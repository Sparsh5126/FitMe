import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _calsController = TextEditingController();
  final _proController = TextEditingController();
  final _carbController = TextEditingController();
  final _fatController = TextEditingController();
  bool _isLoading = false;

  // Instantly calculates a standard 30% Pro / 40% Carb / 30% Fat split
  void _autoCalculateMacros() {
    final cals = int.tryParse(_calsController.text) ?? 2000;
    setState(() {
      _proController.text = ((cals * 0.30) / 4).round().toString();
      _carbController.text = ((cals * 0.40) / 4).round().toString();
      _fatController.text = ((cals * 0.30) / 9).round().toString();
    });
  }

  // Pushes the new goals directly to the user's Firestore document
  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'dailyCalories': int.tryParse(_calsController.text) ?? 2000,
          'dailyProtein': int.tryParse(_proController.text) ?? 150,
          'dailyCarbs': int.tryParse(_carbController.text) ?? 200,
          'dailyFats': int.tryParse(_fatController.text) ?? 66,
        }, SetOptions(merge: true));
      } else {
        throw Exception("User ID is missing. Are you logged in?");
      }
      
      // If successful, go back to the dashboard
      if (mounted) {
        Navigator.pop(context); 
      }
      
    } catch (e) {
      // If it fails, show a red pop-up with the exact error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      // ALWAYS turn off the loading spinner, pass or fail
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Macro Goals', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Daily Target", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildInputField("Calories (kcal)", _calsController, AppTheme.accent),
              
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _autoCalculateMacros,
                  icon: const Icon(Icons.calculate, color: AppTheme.accent),
                  label: const Text("Auto-Calculate 30/40/30 Split", style: TextStyle(color: AppTheme.accent)),
                  style: TextButton.styleFrom(backgroundColor: AppTheme.accent.withOpacity(0.1)),
                ),
              ),
              
              const SizedBox(height: 32),
              const Text("Custom Macros", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(child: _buildInputField("Protein (g)", _proController, Colors.blueAccent)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildInputField("Carbs (g)", _carbController, Colors.orangeAccent)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildInputField("Fats (g)", _fatController, Colors.purpleAccent)),
                ],
              ),

              const Spacer(),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: AppTheme.background)
                      : const Text('Save Goals', style: TextStyle(color: AppTheme.background, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, Color color) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.8), fontSize: 14),
        filled: true,
        fillColor: AppTheme.surface,
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color, width: 2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.transparent)),
      ),
    );
  }
}