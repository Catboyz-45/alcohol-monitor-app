import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_service.dart';
import 'theme.dart';
import 'widgets/common.dart';

// หน้าเข้าสู่ระบบสำหรับเจ้าหน้าที่ (บัญชีสร้างโดยผู้ดูแลใน Firebase Console)
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().signIn(
        _emailController.text,
        _passwordController.text,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: c.primary,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            Icons.air_rounded,
                            size: 34,
                            color: c.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        header: true,
                        child: Text(
                          'Alcohol Monitor',
                          style: TextStyle(
                            fontSize: 30,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'บันทึกผลตรวจแอลกอฮอล์จากเครื่องวัด สำหรับเจ้าหน้าที่',
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: c.muted,
                        ),
                      ),
                      const SizedBox(height: 32),
                      LabeledField(
                        label: 'อีเมล',
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: 'name@agency.go.th',
                          ),
                          validator:
                              (value) =>
                                  value == null || !value.contains('@')
                                      ? 'กรุณากรอกอีเมลให้ถูกต้อง'
                                      : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LabeledField(
                        label: 'รหัสผ่าน',
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            suffixIcon: IconButton(
                              tooltip:
                                  _obscure ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed:
                                  () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator:
                              (value) =>
                                  value == null || value.isEmpty
                                      ? 'กรุณากรอกรหัสผ่าน'
                                      : null,
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: c.dangerSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(color: c.dangerInk),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child:
                            _busy
                                ? SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: c.onPrimary,
                                  ),
                                )
                                : const Text('เข้าสู่ระบบ'),
                      ),
                      const SizedBox(height: 40),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: c.surfaceMuted,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'ยังไม่มีบัญชี?',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: c.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ลองใช้โหมดสาธิตด้วยเครื่องวัดจำลอง ข้อมูลเก็บในเครื่องนี้เท่านั้น',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: c.muted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed:
                                  _busy
                                      ? null
                                      : () =>
                                          context
                                              .read<AuthService>()
                                              .enterDemo(),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: c.surface,
                                minimumSize: const Size(0, 48),
                              ),
                              child: const Text('ทดลองใช้โหมดสาธิต'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
