import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;
import 'package:cockado_enrollapp/core/theme/app_colors.dart';
import 'package:cockado_enrollapp/core/db/database_provider.dart';
import 'package:cockado_enrollapp/core/db/app_database.dart';
import 'package:cockado_enrollapp/features/scan/scan_providers.dart';
import 'package:cockado_enrollapp/shared/widgets/form_field_widget.dart';
import 'package:cockado_enrollapp/shared/widgets/segmented_control.dart';
import 'package:cockado_enrollapp/shared/widgets/option_sheet.dart';

class EnrolmentScreen extends ConsumerStatefulWidget {
  const EnrolmentScreen({super.key});

  @override
  ConsumerState<EnrolmentScreen> createState() => _EnrolmentScreenState();
}

class _EnrolmentScreenState extends ConsumerState<EnrolmentScreen> {
  final _fullNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _baptismDateController = TextEditingController();
  final _tallyController = TextEditingController();

  int _selectedGender = 0;
  String? _selectedMaritalStatus;
  String? _selectedZone;
  DateTime? _dob;
  DateTime? _baptismDate;

  bool _isSaving = false;

  static const _maritalOptions = ['SINGLE', 'MARRIED', 'DIVORCED', 'WIDOWED'];
  static const _zoneOptions = [
    'WUSE ZONE',
    'GARKI ZONE',
    'MAITAMA ZONE',
    'KUBWA ZONE',
    'LUGBE ZONE',
    'OTHER',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(standbyInhibitedProvider.notifier).state = true;
    });
  }

  @override
  void dispose() {
    ref.read(standbyInhibitedProvider.notifier).state = false;
    _fullNameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _baptismDateController.dispose();
    _tallyController.dispose();
    super.dispose();
  }

  String _generateTally() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  Future<void> _pickDate({required bool isBaptism}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isBaptism
          ? (_baptismDate ?? now)
          : (_dob ?? DateTime(now.year - 18)),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      if (isBaptism) {
        _baptismDate = picked;
        _baptismDateController.text = _formatDate(picked);
      } else {
        _dob = picked;
        _dobController.text = _formatDate(picked);
      }
    });
  }

  Future<void> _pickMaritalStatus() async {
    final currentIndex = _selectedMaritalStatus != null
        ? _maritalOptions.indexOf(_selectedMaritalStatus!)
        : 0;
    final result = await OptionSheet.show(
      context,
      title: 'MARITAL STATUS',
      options: _maritalOptions,
      selectedIndex: currentIndex < 0 ? 0 : currentIndex,
    );
    if (result != null) {
      setState(() => _selectedMaritalStatus = _maritalOptions[result]);
    }
  }

  Future<void> _pickZone() async {
    final currentIndex = _selectedZone != null
        ? _zoneOptions.indexOf(_selectedZone!)
        : 0;
    final result = await OptionSheet.show(
      context,
      title: 'ZONE',
      options: _zoneOptions,
      selectedIndex: currentIndex < 0 ? 0 : currentIndex,
    );
    if (result != null) {
      setState(() => _selectedZone = _zoneOptions[result]);
    }
  }

  Future<void> _save() async {
    if (_fullNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Full Name is required.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseProvider);
      final id = const Uuid().v4();

      await db.enrolleesDao.upsertEnrollee(EnrolleesCompanion(
        id: Value(id),
        fullName: Value(_fullNameController.text.trim()),
        email: Value(
          _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
        ),
        phone: Value(
          _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
        ),
        gender: Value(_selectedGender == 0 ? 'M' : 'F'),
        maritalStatus: Value(_selectedMaritalStatus),
        dob: Value(_dob),
        address: Value(
          _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
        ),
        city: Value(
          _cityController.text.trim().isEmpty
              ? null
              : _cityController.text.trim(),
        ),
        zone: Value(_selectedZone),
        baptismDate: Value(_baptismDate),
        tallyNumber: Value(
          _tallyController.text.trim().isEmpty
              ? null
              : _tallyController.text.trim(),
        ),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      await db.syncDao.enqueue(SyncQueueCompanion(
        entityType: Value('enrollee'),
        entityId: Value(id),
        operation: Value('CREATE'),
        payload: Value('{}'),
        createdAt: Value(DateTime.now()),
      ));

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving enrolment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                children: [
                  FormFieldWidget(
                    label: 'FULL NAME',
                    controller: _fullNameController,
                    leadingIcon: Icons.person_outline,
                  ),
                  const SizedBox(height: 12),
                  FormFieldWidget(
                    label: 'DATE OF BIRTH',
                    controller: _dobController,
                    leadingIcon: Icons.calendar_today_outlined,
                    readOnly: true,
                    trailing: const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    onTap: () => _pickDate(isBaptism: false),
                  ),
                  const SizedBox(height: 12),
                  _buildGenderField(),
                  const SizedBox(height: 12),
                  FormFieldWidget(
                    label: 'MARITAL STATUS',
                    controller: TextEditingController(
                      text: _selectedMaritalStatus ?? '',
                    ),
                    readOnly: true,
                    trailing: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                    onTap: _pickMaritalStatus,
                  ),
                  const SizedBox(height: 12),
                  FormFieldWidget(
                    label: 'PHONE',
                    controller: _phoneController,
                    leadingIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  FormFieldWidget(
                    label: 'EMAIL',
                    controller: _emailController,
                    leadingIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  FormFieldWidget(
                    label: 'ADDRESS',
                    controller: _addressController,
                  ),
                  const SizedBox(height: 12),
                  FormFieldWidget(
                    label: 'CITY',
                    controller: _cityController,
                  ),
                  const SizedBox(height: 12),
                  FormFieldWidget(
                    label: 'ZONE',
                    controller: TextEditingController(
                      text: _selectedZone ?? '',
                    ),
                    readOnly: true,
                    trailing: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                    onTap: _pickZone,
                  ),
                  const SizedBox(height: 12),
                  FormFieldWidget(
                    label: 'BAPTISM DATE',
                    controller: _baptismDateController,
                    readOnly: true,
                    trailing: const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    onTap: () => _pickDate(isBaptism: true),
                  ),
                  const SizedBox(height: 12),
                  _buildTallyField(),
                  const SizedBox(height: 24),
                  _buildSaveButton(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.darkCard,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_left,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'NEW ENROLMENT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            GestureDetector(
              onTap: _isSaving ? null : _save,
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: _isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'SAVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GENDER',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedControl(
          options: const ['MALE', 'FEMALE'],
          selectedIndex: _selectedGender,
          onChanged: (index) => setState(() => _selectedGender = index),
        ),
      ],
    );
  }

  Widget _buildTallyField() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: FormFieldWidget(
            label: 'TALLY NUMBER',
            controller: _tallyController,
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 0),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _tallyController.text = _generateTally();
              });
            },
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A5C),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: const Text(
                'GENERATE',
                style: TextStyle(
                  color: AppColors.blue,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue,
          disabledBackgroundColor: AppColors.blue.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'SAVE ENROLMENT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
