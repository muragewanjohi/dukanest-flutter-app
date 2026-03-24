import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _storeUrlController = TextEditingController();
  final _industryController = TextEditingController(); 
  final _phoneController = TextEditingController();
  
  String? _selectedBusinessType;
  String _selectedCountryCode = 'Kenya (+254)';
  bool _isLoading = false;

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeUrlController.dispose();
    _industryController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      final slug = _storeUrlController.text.trim();
      final fallbackEmail = '${slug.isEmpty ? 'owner' : slug}@dukanest.demo';
      ref.read(authProvider.notifier).loginWithDemoUser(email: fallbackEmail);
      setState(() => _isLoading = false);
      context.go('/dashboard');
    });
  }

  Widget _buildFieldLabel(String label, {String? hint}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.secondary,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ]
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.secondary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600), // Desktop limits
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo Header
                    Center(
                      child: Image.asset(
                        'assets/images/logo_with_name.png',
                        height: 48,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    Text(
                      'Start your 14-day free trial',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.secondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Google SSO
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : () {},
                      icon: SvgPicture.asset(
                        'assets/images/google_icon.svg',
                        height: 20,
                        width: 20,
                      ),
                      label: const Text('Continue with Google'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(child: Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('Or continue with email and password', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                        ),
                        Expanded(child: Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
                      ],
                    ),
                    
                    // Fields
                    _buildFieldLabel('Store Name'),
                    TextFormField(
                      controller: _storeNameController,
                      decoration: const InputDecoration(
                        hintText: 'My Store',
                        suffixIcon: Icon(Icons.more_horiz, size: 20, color: Colors.grey),
                      ),
                      onChanged: (val) {
                        // Auto-fill slug if untouched
                        if (_storeUrlController.text.isEmpty || _storeUrlController.text == val.replaceAll(' ', '-').toLowerCase().substring(0, val.length > 1 ? val.length - 1 : 0)) {
                           _storeUrlController.text = val.replaceAll(' ', '-').toLowerCase();
                           setState((){});
                        }
                      },
                    ),

                    _buildFieldLabel('Store URL'),
                    TextFormField(
                      controller: _storeUrlController,
                      decoration: const InputDecoration(
                        hintText: 'my-store',
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        children: [
                          const TextSpan(text: 'dukanest.com/'),
                          TextSpan(
                            text: _storeUrlController.text.isEmpty ? 'my-store' : _storeUrlController.text,
                            style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Text('Choose a unique subdomain', style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey.shade500)),

                    _buildFieldLabel('Business Type'),
                    DropdownMenu<String>(
                      initialSelection: _selectedBusinessType,
                      hintText: 'Select your business type',
                      expandedInsets: EdgeInsets.zero,
                      inputDecorationTheme: const InputDecorationTheme(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      dropdownMenuEntries: ['Retail', 'Wholesale', 'Dropshipping', 'Services'].map((type) {
                        return DropdownMenuEntry(value: type, label: type);
                      }).toList(),
                      onSelected: (v) => setState(() => _selectedBusinessType = v),
                    ),

                    _buildFieldLabel('What are you selling?'),
                    TextFormField(
                      controller: _industryController,
                      decoration: const InputDecoration(
                        hintText: 'What are you selling',
                        suffixIcon: Icon(Icons.more_horiz, size: 20, color: Colors.grey),
                      ),
                    ),

                    _buildFieldLabel(
                      'Store phone number', 
                      hint: 'Receive SMS alerts when customers place orders so you never miss a sale. You can add or change this anytime in settings.',
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: DropdownMenu<String>(
                            initialSelection: _selectedCountryCode,
                            expandedInsets: EdgeInsets.zero,
                            inputDecorationTheme: const InputDecorationTheme(
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            dropdownMenuEntries: ['Kenya (+254)', 'Uganda (+256)', 'Tz (+255)'].map((e) {
                              return DropdownMenuEntry(value: e, label: e);
                            }).toList(),
                            onSelected: (v) => setState(() => _selectedCountryCode = v!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 6,
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              hintText: '712 345 678',
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Info Box
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.primaryContainer.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'We will customize your store based on what you are selling',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.secondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "We'll add demo products so you can see how your store looks right away",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    
                    // Terms and Conditions
                    Center(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                          children: [
                            const TextSpan(text: 'By continuing, you agree to our '),
                            TextSpan(
                              text: 'Terms',
                              style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),

                    // Primary Signature CTA
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primaryContainer, 
                            colorScheme.primary,          
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          stops: const [0.0, 1.0],
                          transform: const GradientRotation(2.35619),
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20, 
                                width: 20, 
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Create My Store'),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
