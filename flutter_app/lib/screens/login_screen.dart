import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final VoidCallback onShowRegister;

  const LoginScreen({super.key, required this.onLoginSuccess, required this.onShowRegister});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for fields from the provided payload
  final _phoneCtrl = TextEditingController();
  final _idDocCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _givenNameCtrl = TextEditingController();
  final _familyNameCtrl = TextEditingController();
  final _nameKanaHankakuCtrl = TextEditingController();
  final _nameKanaZenkakuCtrl = TextEditingController();
  final _middleNamesCtrl = TextEditingController();
  final _familyNameAtBirthCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _streetNameCtrl = TextEditingController();
  final _streetNumberCtrl = TextEditingController();
  final _postalCodeCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _localityCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _houseNumberExtensionCtrl = TextEditingController();
  final _birthdateCtrl = TextEditingController(); // expect YYYY-MM-DD
  final _emailCtrl = TextEditingController();

  String _gender = 'OTHER';
  bool _loading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _idDocCtrl.dispose();
    _nameCtrl.dispose();
    _givenNameCtrl.dispose();
    _familyNameCtrl.dispose();
    _nameKanaHankakuCtrl.dispose();
    _nameKanaZenkakuCtrl.dispose();
    _middleNamesCtrl.dispose();
    _familyNameAtBirthCtrl.dispose();
    _addressCtrl.dispose();
    _streetNameCtrl.dispose();
    _streetNumberCtrl.dispose();
    _postalCodeCtrl.dispose();
    _regionCtrl.dispose();
    _localityCtrl.dispose();
    _countryCtrl.dispose();
    _houseNumberExtensionCtrl.dispose();
    _birthdateCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final payload = {
      'phoneNumber': _phoneCtrl.text.trim(),
      'idDocument': _idDocCtrl.text.trim(),
      'name': _nameCtrl.text.trim(),
      'givenName': _givenNameCtrl.text.trim(),
      'familyName': _familyNameCtrl.text.trim(),
      'nameKanaHankaku': _nameKanaHankakuCtrl.text.trim(),
      'nameKanaZenkaku': _nameKanaZenkakuCtrl.text.trim(),
      'middleNames': _middleNamesCtrl.text.trim(),
      'familyNameAtBirth': _familyNameAtBirthCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'streetName': _streetNameCtrl.text.trim(),
      'streetNumber': _streetNumberCtrl.text.trim(),
      'postalCode': _postalCodeCtrl.text.trim(),
      'region': _regionCtrl.text.trim(),
      'locality': _localityCtrl.text.trim(),
      'country': _countryCtrl.text.trim(),
      'houseNumberExtension': _houseNumberExtensionCtrl.text.trim(),
      'birthdate': _birthdateCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'gender': _gender,
    };

    // Print payload to debug console for testing (replace with API call as needed)
    debugPrint('KYC payload: ${payload.toString()}');

    // Simulate success: show a confirmation and continue
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitted — proceeding')));

    // small delay to allow snackbar to show
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) widget.onLoginSuccess();
    });

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KhetLink KYC', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Please enter your details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _phoneCtrl,
                          decoration: const InputDecoration(labelText: 'Phone Number', hintText: '+919876543210'),
                          validator: (v) => (v?.trim().isEmpty ?? true) ? 'Enter phone number' : null,
                        ),

                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _idDocCtrl,
                          decoration: const InputDecoration(labelText: 'ID Document'),
                        ),

                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(labelText: 'Full name'),
                          validator: (v) => (v?.trim().isEmpty ?? true) ? 'Enter name' : null,
                        ),

                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: TextFormField(controller: _givenNameCtrl, decoration: const InputDecoration(labelText: 'Given name'))),
                          const SizedBox(width: 8),
                          Expanded(child: TextFormField(controller: _familyNameCtrl, decoration: const InputDecoration(labelText: 'Family name'))),
                        ]),

                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: TextFormField(controller: _nameKanaHankakuCtrl, decoration: const InputDecoration(labelText: 'Name Kana (Hankaku)'))),
                          const SizedBox(width: 8),
                          Expanded(child: TextFormField(controller: _nameKanaZenkakuCtrl, decoration: const InputDecoration(labelText: 'Name Kana (Zenkaku)'))),
                        ]),

                        const SizedBox(height: 8),
                        TextFormField(controller: _middleNamesCtrl, decoration: const InputDecoration(labelText: 'Middle names')),
                        const SizedBox(height: 8),
                        TextFormField(controller: _familyNameAtBirthCtrl, decoration: const InputDecoration(labelText: 'Family name at birth')),

                        const SizedBox(height: 8),
                        TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress, validator: (v) {
                          if (v == null || v.trim().isEmpty) return null; // optional
                          return v.contains('@') ? null : 'Enter a valid email';
                        }),

                        const SizedBox(height: 8),
                        TextFormField(controller: _birthdateCtrl, decoration: const InputDecoration(labelText: 'Birthdate (YYYY-MM-DD)'), validator: (v) {
                          if (v == null || v.trim().isEmpty) return null; // optional
                          final regex = RegExp(r'^\d{4}-\d{2}-\d{2}\$');
                          return regex.hasMatch(v.trim()) ? null : 'Use YYYY-MM-DD';
                        }),

                        const SizedBox(height: 8),
                        TextFormField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Address')), 
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: TextFormField(controller: _streetNameCtrl, decoration: const InputDecoration(labelText: 'Street name'))),
                          const SizedBox(width: 8),
                          Expanded(child: TextFormField(controller: _streetNumberCtrl, decoration: const InputDecoration(labelText: 'Street number'))),
                        ]),

                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: TextFormField(controller: _postalCodeCtrl, decoration: const InputDecoration(labelText: 'Postal code'))),
                          const SizedBox(width: 8),
                          Expanded(child: TextFormField(controller: _regionCtrl, decoration: const InputDecoration(labelText: 'Region'))),
                        ]),

                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: TextFormField(controller: _localityCtrl, decoration: const InputDecoration(labelText: 'Locality'))),
                          const SizedBox(width: 8),
                          Expanded(child: TextFormField(controller: _countryCtrl, decoration: const InputDecoration(labelText: 'Country'))),
                        ]),

                        const SizedBox(height: 8),
                        TextFormField(controller: _houseNumberExtensionCtrl, decoration: const InputDecoration(labelText: 'House number extension')),

                        const SizedBox(height: 12),
                        Row(children: [
                          const Text('Gender: '),
                          const SizedBox(width: 8),
                          DropdownButton<String>(value: _gender, items: const [
                            DropdownMenuItem(value: 'MALE', child: Text('Male')),
                            DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                            DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                          ], onChanged: (v) { if (v != null) setState(() => _gender = v); }),
                        ]),

                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(child: ElevatedButton(onPressed: _loading ? null : _submit, child: _loading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Submit'))),
                        ]),

                        const SizedBox(height: 8),
                        TextButton(onPressed: widget.onShowRegister, child: const Text('Create an account')),
                      ],
                    ),
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
