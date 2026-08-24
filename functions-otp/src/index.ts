import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { DocumentReference, FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { defineSecret } from 'firebase-functions/params';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';

import { EXOTEL_SENDER, sendOtpSms } from './exotel';
import {
  MAX_OTP_REQUESTS_PER_WINDOW,
  MAX_VERIFICATION_ATTEMPTS,
  OTP_EXPIRY_SECONDS,
  RATE_LIMIT_WINDOW_SECONDS,
  buildOtpSms,
  generateSalt,
  generateSecureOtp,
  hashOtp,
  normalizePhone,
  parseTestPhones,
  safePlatformName,
  timingSafeCompare
} from './otp';

/**
 * Phone-OTP sign-in for the Divya Teacher Corner Flutter slice.
 *
 * FORKED from ~/code/teacher-corner/functions-otp (the web app's deployed
 * flow), which is left untouched. Three things keep the two apart, and all
 * three matter:
 *
 *   - FUNCTION NAMES. tcDivya*, not tcDev*. Function names are per-project, and
 *     helix-staging-india already runs the web app's tcDevSendOtp /
 *     tcDevVerifyOtp. Same names would overwrite live functions.
 *   - CODEBASE. firebase.json declares codebase 'divya-otp'. The CLI only ever
 *     considers same-codebase functions for deletion, so this deploy cannot
 *     offer to remove the web app's 'tcdev-otp' pair, nor sendWelcomeEmail and
 *     expenseLogTotals sitting in the default codebase.
 *   - DATABASE. teacher-corner-dev, see DATABASE_ID below. NOTE the shared
 *     rate-limit consequence documented there.
 *
 * The Exotel credentials are the SAME Secret Manager secrets. Binding a secret
 * to a new function only grants read access; it does not alter the secret or
 * the functions already bound to it.
 *
 * Implemented from the Exotel OTP guide. Gen2 onCall,
 * asia-south1, credentials from Secret Manager, code generated hashed and
 * verified entirely server-side.
 *
 * THREE DELIBERATE DEPARTURES FROM THE GUIDE, all for isolation on a project
 * that hosts more than one application.
 *
 *   1. NAMES. The guide exports `sendOtp` / `verifyOtp`. Those are generic
 *      enough that another app in this project could want them, and function
 *      names are per-project. Prefixed here so nothing can collide and so the
 *      owner of any function in the console is obvious.
 *
 *   2. DATABASE. The guide uses admin.firestore(), which is the (default)
 *      database — shared with four other apps. This writes to the NAMED
 *      'teacher-corner-dev' database instead, the same one the app reads its
 *      teachers and classrooms from.
 *
 *   3. RATE-LIMIT PERSISTENCE. See the comment on clearChallenge below. The
 *      guide deletes the whole document on expiry, on attempt-exhaustion and on
 *      success, which also discards requestCount and windowStart and so resets
 *      the send cap. Preserved here instead.
 *
 * Everything else — the DLT values, the template body, the constants, the
 * document shape, the field names, the error codes — is the guide's, unchanged.
 */

initializeApp();

/**
 * teacher-corner-dev, on instruction: one database for everything this app
 * touches, and the old divya-teacher-corner retired.
 *
 * READ THIS BEFORE DEPLOYING. That database is owned by the live Teacher Corner
 * web app, and it ALREADY HAS AN OTPVerifications COLLECTION written by its own
 * tcDevSendOtp / tcDevVerifyOtp. Both functions key a document on the normalized
 * phone number, so for a number used in BOTH apps the two now share one
 * document. Three consequences, none of which stops either app working but all
 * of which are real:
 *
 *   - LAST SEND WINS. The document holds ONE hashedOtp and salt, so requesting a
 *     code in one app invalidates any code still outstanding in the other. A
 *     teacher cannot hold two pending challenges at once across the two apps.
 *   - THE SEND CAP IS SHARED. requestCount and windowStart are per document, so
 *     sends from this app count against that number's budget in the web app and
 *     vice versa. That budget is what bounds spend on an Exotel account whose
 *     credentials cannot be rotated, so sharing it is a spend decision as much
 *     as a correctness one.
 *   - ATTEMPTS ARE SHARED. The five-attempt cap is on the document, so failed
 *     attempts in one app consume the other's.
 *
 * A number used in only one app is unaffected. The collision is confined to
 * numbers used in both, and the failure mode is "request a fresh code", not a
 * broken account.
 *
 * IT IS STILL WRITE-SAFE FOR THE WEB APP'S DATA. Only OTPVerifications is
 * touched, a collection the web app treats exactly the same way, and the rules
 * are not deployed from this repo — there is no `firestore` block in
 * firebase.json precisely so that cannot happen.
 */
const DATABASE_ID = 'teacher-corner-dev';

/** Guide's collection name and document key: one doc per normalized phone. */
const COLLECTION = 'OTPVerifications';

const db = getFirestore(DATABASE_ID);

// Declared so a deploy fails loudly if either is missing, rather than the
// function starting and reading an empty credential.
const EXOTEL_AUTH_KEY = defineSecret('EXOTEL_AUTH_KEY');
const EXOTEL_AUTH_TOKEN = defineSecret('EXOTEL_AUTH_TOKEN');

const REGION = 'asia-south1';

interface Challenge {
  hashedOtp: string;
  salt: string;
  expiresAt: Timestamp;
  attempts: number;
  maxAttempts: number;
  createdAt: Timestamp;
  requestCount: number;
  windowStart: Timestamp;
}

/**
 * Retires a challenge without forgetting how many sends the number has had.
 *
 * THE ONE SECURITY DEVIATION FROM THE GUIDE, and the reason for it: the guide
 * calls otpRef.delete() on expiry, on attempt-exhaustion and on success. That
 * document is also where requestCount and windowStart live, so deleting it
 * resets the 3-per-10-minutes send cap.
 *
 * On the success path that is harmless — reaching it required a valid code. On
 * the attempt-exhaustion path it is a bypass: submit five wrong codes, the
 * document is deleted, the cap is clear, request three more, repeat. The cap is
 * the only thing standing between this endpoint and an unbounded bill on an
 * Exotel account whose credentials cannot be rotated, so it is not left
 * resettable by an unauthenticated caller.
 *
 * The challenge material is cleared, which is what deletion was for. Revert to
 * a plain delete() if the guide's exact behaviour is required.
 */
async function clearChallenge(ref: DocumentReference): Promise<void> {
  await ref.update({
    hashedOtp: FieldValue.delete(),
    salt: FieldValue.delete(),
    expiresAt: FieldValue.delete(),
    attempts: FieldValue.delete(),
    maxAttempts: FieldValue.delete(),
    consumedAt: Timestamp.now()
  });
}

// ===========================================================================
// tcDivyaSendOtp
// ===========================================================================

export const tcDivyaSendOtp = onCall(
  {
    region: REGION,
    // REQUIRED. A provisioned secret is not in process.env until it is bound to
    // the function; without this the credential reads '' and Exotel answers 401
    // with no SMS and nothing obviously wrong.
    secrets: [EXOTEL_AUTH_KEY, EXOTEL_AUTH_TOKEN]
  },
  async request => {
    const { phone } = (request.data ?? {}) as { phone?: string };

    if (!phone || typeof phone !== 'string') {
      throw new HttpsError('invalid-argument', 'Phone number is required.');
    }

    const platformName = safePlatformName((request.data as { platformName?: unknown })?.platformName);
    const normalizedPhone = normalizePhone(phone);
    const ref = db.collection(COLLECTION).doc(normalizedPhone);
    const now = Timestamp.now();

    // ---- Rate limit: 3 sends per phone per rolling 10 minutes ----
    const snapshot = await ref.get();
    const existing = snapshot.exists ? (snapshot.data() as Partial<Challenge>) : undefined;

    let requestCount = 1;
    let windowStart = now;

    if (existing?.windowStart) {
      const elapsedSeconds = (now.toMillis() - existing.windowStart.toMillis()) / 1000;

      if (elapsedSeconds < RATE_LIMIT_WINDOW_SECONDS) {
        if ((existing.requestCount ?? 0) >= MAX_OTP_REQUESTS_PER_WINDOW) {
          throw new HttpsError(
            'resource-exhausted',
            'Too many OTP requests. Please try again in a few minutes.'
          );
        }

        requestCount = (existing.requestCount ?? 0) + 1;
        windowStart = existing.windowStart;
      }
      // Window elapsed: fall through, which restarts it at 1 send from now.
    }

    // ---- Generate, hash, store. The plaintext code is never persisted. ----
    const otp = generateSecureOtp();
    const salt = generateSalt();

    await ref.set({
      hashedOtp: hashOtp(otp, salt),
      salt,
      expiresAt: Timestamp.fromMillis(now.toMillis() + OTP_EXPIRY_SECONDS * 1000),
      attempts: 0,
      maxAttempts: MAX_VERIFICATION_ATTEMPTS,
      createdAt: now,
      requestCount,
      windowStart
    });

    // ---- Log the code and skip the send, when it would be wrong to send ----
    //
    // Two cases, and the emulator one is not in the guide.
    //
    // TEST_PHONES is the guide's allowlist. It is the only safe way to exercise a
    // DEPLOYED function, because these credentials reach real handsets and bill a
    // production account with no sandbox.
    //
    // FUNCTIONS_EMULATOR covers every number when running locally. The emulator
    // has no business calling Exotel at all: the credentials it holds are the
    // placeholders in .secret.local, so a send can only ever 401, and the failure
    // reads as "the code could not be sent" rather than "you are running locally
    // and this number is not in TEST_PHONES". Worse, if someone runs the emulator
    // WITHOUT .secret.local, firebase-tools fetches the real credentials and a
    // local test would fire a real, billed SMS. Skipping the send locally removes
    // both. Set by the Functions emulator itself and never present in production.
    const isEmulator = process.env.FUNCTIONS_EMULATOR === 'true';

    if (isEmulator || parseTestPhones(process.env.TEST_PHONES).has(normalizedPhone)) {
      logger.info(`[TEST-OTP] phone=${normalizedPhone} otp=${otp}`);
      return { success: true, expiresInSeconds: OTP_EXPIRY_SECONDS };
    }

    try {
      await sendOtpSms(
        normalizedPhone,
        buildOtpSms(otp, platformName),
        // Read INSIDE the handler. At module scope these are not yet populated
        // and would resolve to empty strings.
        EXOTEL_AUTH_KEY.value(),
        EXOTEL_AUTH_TOKEN.value()
      );
    } catch (error) {
      logger.error('OTP send failed', { to: normalizedPhone, sender: EXOTEL_SENDER });
      throw new HttpsError('internal', 'Failed to send SMS. Please try again.');
    }

    // The code is never returned to the caller.
    return { success: true, expiresInSeconds: OTP_EXPIRY_SECONDS };
  }
);

// ===========================================================================
// tcDivyaVerifyOtp
// ===========================================================================

export const tcDivyaVerifyOtp = onCall(
  // No Exotel secrets: nothing here sends anything.
  { region: REGION },
  async request => {
    const { phone, otp } = (request.data ?? {}) as { phone?: string; otp?: string };

    if (!phone || !otp) {
      throw new HttpsError('invalid-argument', 'Phone number and OTP are required.');
    }

    const normalizedPhone = normalizePhone(phone);
    const ref = db.collection(COLLECTION).doc(normalizedPhone);
    const snapshot = await ref.get();
    const challenge = snapshot.exists ? (snapshot.data() as Partial<Challenge>) : undefined;

    if (!challenge?.hashedOtp || !challenge.salt || !challenge.expiresAt) {
      throw new HttpsError('not-found', 'No OTP found. Please request a new one.');
    }

    if (Timestamp.now().toMillis() > challenge.expiresAt.toMillis()) {
      await clearChallenge(ref);
      throw new HttpsError('deadline-exceeded', 'OTP has expired. Please request a new one.');
    }

    const attempts = challenge.attempts ?? 0;
    const maxAttempts = challenge.maxAttempts ?? MAX_VERIFICATION_ATTEMPTS;

    // A six-digit code is a million possibilities, which a script walks in
    // minutes if nothing counts the failures.
    if (attempts >= maxAttempts) {
      await clearChallenge(ref);
      throw new HttpsError('resource-exhausted', 'Too many failed attempts. Request a new OTP.');
    }

    if (!timingSafeCompare(hashOtp(String(otp), challenge.salt), challenge.hashedOtp)) {
      await ref.update({ attempts: FieldValue.increment(1) });
      const remaining = maxAttempts - attempts - 1;
      throw new HttpsError('permission-denied', `Invalid OTP. ${remaining} attempt(s) remaining.`);
    }

    // ---- Correct. Mint the session. ----
    //
    // The guide stops at { success: true } and leaves "mint a custom token" as
    // the caller's business. A login flow needs the token, so it is minted here.
    //
    // TWO PREREQUISITES, neither of which this code can satisfy on its own:
    //   - the runtime service account needs roles/iam.serviceAccountTokenCreator
    //     on itself, or createCustomToken fails with a permission error;
    //   - createUser fires this project's EXISTING beforeCreate blocking Auth
    //     trigger, sendWelcomeEmail, which belongs to another app. Whether it
    //     tolerates a user with no email address is unverified.
    const { token, uid } = await mintToken(normalizedPhone);

    // Cleared only AFTER the token exists, so a failure above does not strand
    // the user having spent a valid code.
    await clearChallenge(ref);

    // AFTER the token, and deliberately not awaited for its result being
    // required: linking is bookkeeping, and a teacher must never lose a
    // sign-in because it failed. See the function's own comment.
    await linkTeacherRecord(normalizedPhone, uid);

    return { success: true, token };
  }
);

/** The collection of teacher records an administrator registers. */
const TEACHERS_COLLECTION = 'teachers';

/**
 * Records a verified teacher's Auth uid on their teaching record.
 *
 * THIS IS THE SAME OPERATION `TeacherService.linkSignedInUid` PERFORMS IN THE
 * WEB APP, moved to where this app's sign-ins actually happen. That function
 * runs on a WEB sign-in, so a teacher an administrator registered whose first
 * sign-in is in the Flutter app was never linked at all: their record sat in
 * `teachers` with their classrooms on it and `teacherMeta.uid` empty, and the
 * app could only find it by falling back to matching the phone number on every
 * launch. Stamping it here closes that for good, for both apps.
 *
 * WHY HERE AND NOT IN THE CLIENT. This is a write into a collection the Flutter
 * app otherwise only reads, and the client has no business holding that
 * privilege. Here it runs with the Admin SDK at the one moment the phone number
 * is PROVEN — a correct OTP was just presented for it — so the number is
 * evidence rather than a claim.
 *
 * MATCHED ON THE SUBSCRIBER DIGITS, which is the key the web app matches on:
 * `teacherMeta.phoneNumber` and `teacherMeta.phone` both hold them, so both are
 * tried. Firestore cannot OR across two fields in one query.
 *
 * ONLY FILLS A BLANK, exactly as the web app does. A record already carrying a
 * uid is left alone: phone numbers get recycled, and overwriting would hand one
 * person another's classrooms. A record already carrying THIS uid needs nothing.
 *
 * BEST EFFORT, AND THAT IS LOAD-BEARING. Every failure is swallowed after
 * logging. A teacher presenting a correct code has earned their session, and
 * must not lose it because a bookkeeping write failed — the client's phone
 * fallback still resolves their record in that case, so the only cost of failing
 * here is that it stays unlinked and is retried next sign-in.
 */
async function linkTeacherRecord(phoneNumber: string, uid: string): Promise<void> {
  try {
    const digits = phoneNumber.replace(/\D/g, '').slice(-10);
    if (digits.length < 10) return;

    for (const field of ['teacherMeta.phoneNumber', 'teacherMeta.phone']) {
      const matches = await db
        .collection(TEACHERS_COLLECTION)
        .where(field, '==', digits)
        // A handful is plenty for one number, and a cap stops a pathological
        // query fanning out on a shared database.
        .limit(5)
        .get();

      for (const doc of matches.docs) {
        const stamped = (doc.data().teacherMeta ?? {}).uid;
        if (stamped) continue; // Somebody's already, possibly somebody else's.

        // DOTTED PATHS, so nothing else on teacherMeta is rewritten from a copy
        // read a moment ago. updatedAt moves because the document did change.
        await doc.ref.update({
          'teacherMeta.uid': uid,
          'teacherMeta.updatedAt': FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp()
        });
        logger.info('Linked a teacher record to a verified uid', {
          teacherDoc: doc.id
        });
        return; // One person, one record. Stop at the first blank filled.
      }
    }
  } catch (error) {
    logger.error('Could not link the teacher record; sign-in is unaffected', {
      message: (error as { message?: string }).message
    });
  }
}

/**
 * Finds or creates the Auth user for a phone number and mints a custom token.
 *
 * Keyed on the phone number: getUserByPhoneNumber first, so a returning teacher
 * keeps their uid and everything stored under it. Creating first and catching
 * the already-exists error would work too, but it fires the project's
 * beforeCreate trigger on every sign-in rather than only on registration.
 */
async function mintToken(
  phoneNumber: string
): Promise<{ token: string; uid: string }> {
  const auth = getAuth();

  let uid: string;

  try {
    uid = (await auth.getUserByPhoneNumber(phoneNumber)).uid;
  } catch (error) {
    if ((error as { code?: string }).code !== 'auth/user-not-found') {
      throw error;
    }

    try {
      uid = (await auth.createUser({ phoneNumber })).uid;
    } catch (createError) {
      logger.error('Could not create the Auth user for a verified phone number', {
        code: (createError as { code?: string }).code
      });
      throw new HttpsError('internal', 'Verified, but the account could not be created.');
    }
  }

  try {
    return { token: await auth.createCustomToken(uid), uid };
  } catch (error) {
    logger.error('createCustomToken failed. Check serviceAccountTokenCreator on the runtime SA.', {
      code: (error as { code?: string }).code
    });
    throw new HttpsError('internal', 'Verified, but the login token could not be issued.');
  }
}
