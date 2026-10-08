import 'package:flutter/material.dart';

class EditMedicationScreen extends StatefulWidget {
  const EditMedicationScreen({super.key});

  @override
  State<EditMedicationScreen> createState() => _EditMedicationScreenState();
}

class _EditMedicationScreenState extends State<EditMedicationScreen> {
  bool reminderEnabled = true;

  final TextEditingController nameController =
      TextEditingController(text: 'Doliprane');

  final TextEditingController dosageController =
      TextEditingController(text: '500 mg');

  final TextEditingController timeController =
      TextEditingController(text: '08:00');

  final TextEditingController startDateController =
      TextEditingController(text: '08/10/2026');

  final TextEditingController endDateController =
      TextEditingController(text: '15/10/2026');

  @override
  void dispose() {
    nameController.dispose();
    dosageController.dispose();
    timeController.dispose();
    startDateController.dispose();
    endDateController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(
        hour: 8,
        minute: 0,
      ),
    );

    if (selectedTime != null) {
      setState(() {
        timeController.text = selectedTime.format(context);
      });
    }
  }

  Future<void> _selectStartDate() async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(2026, 10, 8),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (selectedDate != null) {
      setState(() {
        startDateController.text =
            '${selectedDate.day.toString().padLeft(2, '0')}/'
            '${selectedDate.month.toString().padLeft(2, '0')}/'
            '${selectedDate.year}';
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(2026, 10, 15),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (selectedDate != null) {
      setState(() {
        endDateController.text =
            '${selectedDate.day.toString().padLeft(2, '0')}/'
            '${selectedDate.month.toString().padLeft(2, '0')}/'
            '${selectedDate.year}';
      });
    }
  }

  void _saveChanges() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Modifications enregistrées avec succès',
        ),
        backgroundColor: Color(0xFF0D9488),
      ),
    );

    Future.delayed(
      const Duration(milliseconds: 700),
      () {
        if (mounted) {
          Navigator.pop(context);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Modifier le médicament',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF0F172A),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Modifier le traitement',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Mettez à jour les informations de votre médicament.',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF64748B),
              ),
            ),

            const SizedBox(height: 25),

            _buildTextField(
              label: 'Nom du médicament',
              icon: Icons.medication_outlined,
              controller: nameController,
            ),

            const SizedBox(height: 16),

            _buildTextField(
              label: 'Dosage',
              icon: Icons.science_outlined,
              controller: dosageController,
            ),

            const SizedBox(height: 16),

            _buildPickerField(
              label: 'Horaire de prise',
              icon: Icons.access_time,
              controller: timeController,
              onTap: _selectTime,
            ),

            const SizedBox(height: 16),

            _buildPickerField(
              label: 'Date de début',
              icon: Icons.calendar_today_outlined,
              controller: startDateController,
              onTap: _selectStartDate,
            ),

            const SizedBox(height: 16),

            _buildPickerField(
              label: 'Date de fin',
              icon: Icons.event_outlined,
              controller: endDateController,
              onTap: _selectEndDate,
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                ),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Activer les rappels',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                subtitle: const Text(
                  'Recevoir un rappel avant la prise',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                  ),
                ),
                secondary: const Icon(
                  Icons.notifications_outlined,
                  color: Color(0xFF0D9488),
                ),
                activeColor: const Color(0xFF0D9488),
                value: reminderEnabled,
                onChanged: (value) {
                  setState(() {
                    reminderEnabled = value;
                  });
                },
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _saveChanges,
                icon: const Icon(
                  Icons.save_outlined,
                ),
                label: const Text(
                  'Enregistrer les modifications',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
  }) {
    return TextField(
      controller: controller,
      decoration: _inputDecoration(
        label: label,
        icon: icon,
      ),
    );
  }

  Widget _buildPickerField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required VoidCallback onTap,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: _inputDecoration(
        label: label,
        icon: icon,
        suffixIcon: Icons.chevron_right,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    IconData? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,

      prefixIcon: Icon(
        icon,
        color: const Color(0xFF0D9488),
      ),

      suffixIcon: suffixIcon != null
          ? Icon(
              suffixIcon,
              color: const Color(0xFF94A3B8),
            )
          : null,

      filled: true,
      fillColor: Colors.white,

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFE2E8F0),
        ),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFE2E8F0),
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFF0D9488),
          width: 2,
        ),
      ),
    );
  }
}