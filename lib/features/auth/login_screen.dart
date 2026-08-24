import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/tc_brand_tile.dart';
import '../../core/widgets/tc_button.dart';
import '../../core/widgets/tc_status_message.dart';
import 'auth_provider.dart';
import 'widgets/otp_code_field.dart';

/// Phone sign-in: number, then code — laid out to the approved 2026-08 mockups.
///
/// The screen navigates nowhere on success. The router's redirect owns that,
/// driven off `AuthProvider` as `refreshListenable`, so there is one place that
/// decides where an authenticated teacher belongs.
///
/// Both stages are one screen, not two routes. They look like separate pages
/// (the code stage has its own navy app bar and back arrow) but the stage lives
/// in `AuthProvider`, and splitting it into routes would put the same state in
/// two places and give the back gesture a second, conflicting meaning.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// ONE KEY PER STAGE, and that separation is the fix for a real bug.
  ///
  /// Both stages wrap their field in a `Form`, and they used to SHARE one key.
  /// Only one stage is mounted at a time so nothing crashed, but it meant
  /// `_formKey.currentState.validate()` validated whichever field happened to be
  /// on screen rather than the one the action was about. Tapping Resend on the
  /// code stage therefore validated the OTP box — empty or partial precisely
  /// when a teacher wants a new code — failed, and returned without sending
  /// anything, while showing a "enter the 6-digit code" error for a button that
  /// has nothing to do with the code.
  final _phoneFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  static const int _codeLength = 6;
  static const int _phoneLength = 10;

  /// How long before "Resend OTP" becomes tappable. Firebase itself rate-limits
  /// resends; this stops a teacher hammering the button before that answers.
  static const int _resendWindowSeconds = 45;

  /// Starts unticked, and cannot be ticked until there is a number to consent
  /// about. Consent to receive an OTP on *no* number is not consent to anything,
  /// so a pre-ticked box would be consent theatre twice over: unasked for, and
  /// attached to nothing.
  bool _consentGiven = false;

  /// Whether the number field holds a full ten digits. Tracked as state rather
  /// than read inline so the rebuild happens once when it flips, not on every
  /// keystroke.
  ///
  /// Deliberately a length check, not `kIndianMobile`. A ten-digit number
  /// starting with 5 is full but invalid, and gating on the regex would leave
  /// the box and the button dead with nothing on screen explaining why. Let the
  /// field's validator say that out loud on submit instead.
  bool _phoneFilled = false;

  Timer? _resendTimer;

  /// Starts at the full window, not zero: the code stage is only ever reached
  /// by sending a code, so "resend already available" is never the truth on
  /// arrival, and the mockup draws it counting down with the action greyed.
  int _resendRemaining = _resendWindowSeconds;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// Rebuilds only on the transition into or out of "ten digits present", so
  /// typing the first nine costs nothing.
  void _onPhoneChanged() {
    final filled = _phoneController.text.trim().length == _phoneLength;
    if (filled == _phoneFilled) return;
    setState(() {
      _phoneFilled = filled;
      // Withdrawing the number withdraws the consent with it. Without this the
      // box could sit ticked over an emptied field, which is the exact state
      // the unticked default exists to prevent.
      if (!filled) _consentGiven = false;
    });
  }

  /// Started only from a real send, never from `initState`.
  ///
  /// A periodic timer running whenever the code stage is on screen would make
  /// `pumpAndSettle` spin forever, so every widget and golden test that pumps
  /// straight into this stage would hang. Tests that drive the button get the
  /// countdown; tests that just render the stage see its opening value.
  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendRemaining = _resendWindowSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendRemaining--);
      if (_resendRemaining <= 0) timer.cancel();
    });
  }

  /// First send, from the phone stage. Validates the PHONE form.
  Future<void> _sendOtp(AuthProvider auth) async {
    if (!(_phoneFormKey.currentState?.validate() ?? false)) return;
    // Clear any stale code before a fresh send, so a code typed against the
    // previous number cannot be submitted against this one.
    _codeController.clear();
    await auth.sendOtp(_phoneController.text.trim());
    if (!mounted) return;
    _startResendCountdown();
  }

  /// Resend, from the code stage.
  ///
  /// DELIBERATELY DOES NOT VALIDATE ANY FORM. The only form mounted here holds
  /// the OTP field, and requiring a valid code before sending a new one is
  /// backwards: a teacher taps this precisely because they have no usable code.
  ///
  /// The number is re-checked directly instead. That is not ceremony — it is the
  /// same guard the phone stage applies, and it is the one thing that must still
  /// hold, since a resend spends a real SMS against a production Exotel account.
  Future<void> _resendOtp(AuthProvider auth) async {
    final digits = _phoneController.text.trim();
    if (!kIndianMobile.hasMatch(digits)) {
      // Should be unreachable: reaching the code stage required a valid number.
      // Sending the teacher back to fix it beats silently doing nothing.
      _changeNumber(auth);
      return;
    }
    // The old code is void the moment a new one is requested, so it goes now
    // rather than being left in the boxes to be submitted against the new
    // challenge and burn one of the server's five attempts.
    _codeController.clear();
    await auth.sendOtp(digits);
    if (!mounted) return;
    _startResendCountdown();
  }

  Future<void> _verifyOtp(AuthProvider auth) async {
    if (!(_codeFormKey.currentState?.validate() ?? false)) return;
    await auth.verifyOtp(_codeController.text.trim());
  }

  void _changeNumber(AuthProvider auth) {
    _resendTimer?.cancel();
    setState(() => _resendRemaining = 0);
    auth.changeNumber();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return auth.stage == LoginStage.phoneEntry
        ? _phoneStage(auth)
        : _codeStage(auth);
  }

  // ───────────────────────── stage 1: the number ──────────────────────────

  Widget _phoneStage(AuthProvider auth) {
    return Scaffold(
      // White, not navy: the sheet runs to the bottom of the screen, and the
      // navy is a block at the top rather than the page's ground.
      backgroundColor: AppColors.white,
      body: SingleChildScrollView(
        // Scrollable rather than an Expanded split: the software keyboard and
        // landscape both shrink the viewport below the content height, and a
        // fixed column simply overflows.
        child: Form(
          key: _phoneFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _navyBrandHeader(),
              // Lifts the sheet's rounded corners over the navy above it.
              // Transform does not affect layout, so it cannot overflow; the
              // matching gap it leaves below is white on a white scaffold.
              Transform.translate(
                offset: Offset(0, -AppDimensions.spacing20),
                child: _welcomeSheet(auth),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navyBrandHeader() {
    return Container(
      width: double.infinity,
      color: AppColors.navy,
      padding: EdgeInsets.only(
        top: AppDimensions.spacing32 + MediaQuery.of(context).padding.top,
        bottom: AppDimensions.spacing32 + AppDimensions.spacing20,
        left: AppDimensions.spacing24,
        right: AppDimensions.spacing24,
      ),
      child: Column(
        children: [
          const TcBrandTile(size: 76, logoSize: 46),
          SizedBox(height: AppDimensions.spacing12),
          Text(
            'auth.title'.tr(),
            textAlign: TextAlign.center,
            style: AppTypography.sectionTitle.copyWith(
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _welcomeSheet(AuthProvider auth) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusSheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppDimensions.spacing24,
        AppDimensions.spacing12,
        AppDimensions.spacing24,
        AppDimensions.spacing32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _sheetHandle()),
          SizedBox(height: AppDimensions.spacing24),
          Text('auth.welcome_title'.tr(), style: AppTypography.heading1),
          SizedBox(height: AppDimensions.spacing4),
          Text('auth.welcome_subtitle'.tr(), style: AppTypography.bodySmall),
          SizedBox(height: AppDimensions.spacing24),

          if (auth.errorKey != null) ...[
            TcStatusBanner(
              type: TcMsgType.error,
              message: auth.errorKey!.tr(),
              onDismiss: auth.clearError,
            ),
            SizedBox(height: AppDimensions.spacing16),
          ],

          Text(
            'auth.phone_label'.tr().toUpperCase(),
            style: AppTypography.label.copyWith(letterSpacing: 1.2),
          ),
          SizedBox(height: AppDimensions.spacing8),
          _phoneRow(),
          SizedBox(height: AppDimensions.spacing16),
          _consentRow(),
          SizedBox(height: AppDimensions.spacing24),
          TcButton(
            label: 'auth.send_otp'.tr(),
            variant: TcButtonVariant.navy,
            isLoading: auth.isBusy,
            // Both gates, in order: a number to send to, then permission to
            // send it. Either one missing and there is nothing to do.
            onPressed: _phoneFilled && _consentGiven
                ? () => _sendOtp(auth)
                : null,
          ),
          SizedBox(height: AppDimensions.spacing32),
          Center(
            child: Text(
              'app.brand'.tr(),
              style: AppTypography.label.copyWith(color: AppColors.skyBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetHandle() {
    return Container(
      width: 40.w,
      height: 4.h,
      decoration: BoxDecoration(
        color: AppColors.borderLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusInput),
      ),
    );
  }

  /// The dial code as its own bordered box, per the mockup, rather than a
  /// prefix inside the field.
  Widget _phoneRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: AppDimensions.inputHeight,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderInput),
            borderRadius: BorderRadius.circular(AppDimensions.radiusInput),
          ),
          child: Text(
            kDialCode,
            style: AppTypography.inputText.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
        ),
        SizedBox(width: AppDimensions.spacing12),
        Expanded(
          child: TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: AppTypography.inputText,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_phoneLength),
            ],
            decoration: InputDecoration(
              hintText: 'auth.phone_hint'.tr(),
              hintStyle: AppTypography.inputText.copyWith(
                color: AppColors.textDisabled,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppDimensions.spacing16,
                vertical: AppDimensions.spacing16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusInput),
                borderSide: const BorderSide(color: AppColors.borderInput),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusInput),
                borderSide: const BorderSide(color: AppColors.borderInput),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusInput),
                borderSide: const BorderSide(color: AppColors.skyBlue),
              ),
            ),
            validator: (value) => kIndianMobile.hasMatch((value ?? '').trim())
                ? null
                : 'auth.phone_invalid'.tr(),
          ),
        ),
      ],
    );
  }

  Widget _consentRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24.r,
          height: 24.r,
          child: Checkbox(
            value: _consentGiven,
            // A null onChanged is what actually disables a Checkbox and greys
            // it, rather than merely ignoring the tap. Until ten digits are in
            // there is nothing to consent about, so the box is not offered.
            onChanged: _phoneFilled
                ? (next) => setState(() => _consentGiven = next ?? false)
                : null,
            activeColor: AppColors.skyBlue,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        SizedBox(width: AppDimensions.spacing12),
        // Expanded, so the sentence wraps instead of overflowing at the font
        // ceiling.
        Expanded(
          child: Text.rich(
            TextSpan(
              // Greys with the box. A disabled control beside full-strength
              // label text reads as a bug rather than as "not yet".
              style: _phoneFilled
                  ? AppTypography.caption
                  : AppTypography.caption.copyWith(
                      color: AppColors.textDisabled,
                    ),
              // ONE SPAN NOW. "Terms apply." was a second, blue, semibold span
              // beside this one and was removed on instruction. Kept as a
              // RichText with a single child rather than collapsed to a Text so
              // the disabled-state styling above still applies to the label as a
              // whole, and so a second span can come back without restructuring.
              children: [TextSpan(text: 'auth.consent'.tr())],
            ),
          ),
        ),
      ],
    );
  }

  // ────────────────────────── stage 2: the code ───────────────────────────

  Widget _codeStage(AuthProvider auth) {
    final canResend = _resendRemaining <= 0;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          // The mockup replaces the old "Change number" text button with this
          // arrow. Same action, so the number stays editable.
          onPressed: auth.isBusy ? null : () => _changeNumber(auth),
          tooltip: 'auth.change_number'.tr(),
        ),
        title: Row(
          children: [
            SvgPicture.asset(
              'assets/images/thinktacLogo_white.svg',
              width: 28.r,
              semanticsLabel: 'app.title'.tr(),
            ),
            SizedBox(width: AppDimensions.spacing16),
            Flexible(
              child: Text(
                'auth.verify_title'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.appBarTitle,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing24,
          vertical: AppDimensions.spacing32,
        ),
        child: Form(
          key: _codeFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: _phoneIconTile()),
              SizedBox(height: AppDimensions.spacing20),
              Text(
                'auth.otp_prompt'.tr(),
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: AppDimensions.spacing8),
              Text(
                _groupedPhone(auth.pendingPhoneNumber),
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              SizedBox(height: AppDimensions.spacing24),

              if (auth.errorKey != null) ...[
                TcStatusBanner(
                  type: TcMsgType.error,
                  message: auth.errorKey!.tr(),
                  onDismiss: auth.clearError,
                ),
                SizedBox(height: AppDimensions.spacing16),
              ],

              OtpCodeField(
                controller: _codeController,
                length: _codeLength,
                validator: (value) =>
                    (value ?? '').trim().length == _codeLength
                        ? null
                        : 'auth.otp_invalid'.tr(),
              ),
              SizedBox(height: AppDimensions.spacing16),
              _resendRow(auth, canResend: canResend),
              SizedBox(height: AppDimensions.spacing24),
              // Rebuilds on every keystroke so the CTA enables the moment the
              // sixth digit lands, without a setState on the whole screen.
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _codeController,
                builder: (context, value, _) => TcButton(
                  label: 'auth.verify'.tr(),
                  variant: TcButtonVariant.navy,
                  isLoading: auth.isBusy,
                  onPressed: value.text.trim().length == _codeLength
                      ? () => _verifyOtp(auth)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _phoneIconTile() {
    final size = 88.r;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.skyBg,
        borderRadius: BorderRadius.circular(size * 0.27),
      ),
      child: Icon(Icons.phone, color: AppColors.skyBlue, size: size * 0.42),
    );
  }

  Widget _resendRow(AuthProvider auth, {required bool canResend}) {
    // Wrap, not Row: at the font ceiling the countdown and the action together
    // exceed a 360dp width, which is the overflow this screen already hit once.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      runSpacing: AppDimensions.spacing8,
      children: [
        Text(
          canResend
              ? ''
              : 'auth.resend_in'.tr(args: ['$_resendRemaining']),
          style: AppTypography.caption,
        ),
        GestureDetector(
          onTap: canResend && !auth.isBusy ? () => _resendOtp(auth) : null,
          child: Text(
            'auth.resend_otp'.tr(),
            style: AppTypography.label.copyWith(
              color: canResend ? AppColors.skyBlue : AppColors.textDisabled,
            ),
          ),
        ),
      ],
    );
  }

  /// `+919876543210` reads as one long digit run; the mockup groups it. Falls
  /// back to the raw value for anything that is not the expected shape, so an
  /// unexpected format is shown rather than mangled.
  String _groupedPhone(String raw) {
    final match = RegExp(r'^(\+\d{2})(\d{5})(\d{5})$').firstMatch(raw);
    if (match == null) return raw;
    return '${match.group(1)} ${match.group(2)} ${match.group(3)}';
  }
}
