import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/tc_button.dart';
import '../../core/widgets/tc_input.dart';
import '../../core/widgets/tc_status_message.dart';
import 'auth_provider.dart';

/// Phone sign-in: number, then code.
///
/// The screen navigates nowhere on success. The router's redirect owns that,
/// driven off `AuthProvider` as `refreshListenable`, so there is one place that
/// decides where an authenticated teacher belongs.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  static const int _codeLength = 6;
  static const int _phoneLength = 10;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _onPrimaryPressed(AuthProvider auth) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (auth.stage == LoginStage.phoneEntry) {
      // Clear any stale code before a fresh send, so a code typed against the
      // previous number cannot be submitted against this one.
      _codeController.clear();
      await auth.sendOtp(_phoneController.text.trim());
    } else {
      await auth.verifyOtp(_codeController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isPhoneStage = auth.stage == LoginStage.phoneEntry;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          // Scrollable rather than a fixed column: the software keyboard and
          // landscape both shrink the viewport below the content height, and a
          // Column would simply overflow.
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing24,
            vertical: AppDimensions.spacing32,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: AppDimensions.spacing24),
                Center(
                  child: SvgPicture.asset(
                    'assets/images/thinktacLogo_color.svg',
                    width: 150.w,
                    semanticsLabel: 'app.title'.tr(),
                  ),
                ),
                SizedBox(height: AppDimensions.spacing32),
                Text('auth.title'.tr(), style: AppTypography.heading2),
                SizedBox(height: AppDimensions.spacing8),
                Text('auth.subtitle'.tr(), style: AppTypography.caption),
                SizedBox(height: AppDimensions.spacing24),

                if (auth.errorKey != null) ...[
                  TcStatusBanner(
                    type: TcMsgType.error,
                    message: auth.errorKey!.tr(),
                    onDismiss: auth.clearError,
                  ),
                  SizedBox(height: AppDimensions.spacing16),
                ],

                if (isPhoneStage) _phoneField() else _codeField(auth),

                SizedBox(height: AppDimensions.spacing24),
                TcButton(
                  label: isPhoneStage
                      ? 'auth.send_otp'.tr()
                      : 'auth.verify'.tr(),
                  isLoading: auth.isBusy,
                  onPressed: () => _onPrimaryPressed(auth),
                ),

                if (!isPhoneStage) ...[
                  SizedBox(height: AppDimensions.spacing8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: auth.isBusy ? null : auth.changeNumber,
                        child: Text(
                          'auth.change_number'.tr(),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.skyBlue,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: auth.isBusy
                            ? null
                            : () => auth.sendOtp(_phoneController.text.trim()),
                        child: Text(
                          'auth.resend_otp'.tr(),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.skyBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _phoneField() {
    return TcInput(
      label: 'auth.phone_label'.tr(),
      hint: 'auth.phone_hint'.tr(),
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(_phoneLength),
      ],
      prefixIcon: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacing12),
        child: Center(child: Text(kDialCode, style: AppTypography.inputText)),
      ),
      validator: (value) => kIndianMobile.hasMatch((value ?? '').trim())
          ? null
          : 'auth.phone_invalid'.tr(),
    );
  }

  Widget _codeField(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'auth.otp_sent'.tr(args: [auth.pendingPhoneNumber]),
          style: AppTypography.caption,
        ),
        SizedBox(height: AppDimensions.spacing12),
        TcInput(
          label: 'auth.otp_label'.tr(),
          hint: 'auth.otp_hint'.tr(),
          controller: _codeController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(_codeLength),
          ],
          validator: (value) => (value ?? '').trim().length == _codeLength
              ? null
              : 'auth.otp_invalid'.tr(),
        ),
      ],
    );
  }
}
