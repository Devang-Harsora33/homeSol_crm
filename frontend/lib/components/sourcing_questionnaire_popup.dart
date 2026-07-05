import 'package:flutter/material.dart';
import 'package:Homesol/utils/custom_snackbar.dart';
import 'package:Homesol/models/sourcing.dart';
import 'package:Homesol/services/apis/sourcing/sourcing_service.dart';

const Color goldAccent = Color(0xFF675D40);
const Color matteBlack = Color(0xFF1A1A1A);
const Color kBackgroundColor = Color(0xFFF2F2F7);

class SourcingQuestionnairePopup extends StatefulWidget {
  final Sourcing source;
  final int? initialCalculatedMinutes;
  final String Function(int) durationStringGenerator;
  final VoidCallback onSaved;

  const SourcingQuestionnairePopup({
    super.key,
    required this.source,
    this.initialCalculatedMinutes,
    required this.durationStringGenerator,
    required this.onSaved,
  });

  @override
  State<SourcingQuestionnairePopup> createState() => _SourcingQuestionnairePopupState();
}

class _SourcingQuestionnairePopupState extends State<SourcingQuestionnairePopup> {
  bool _isLoading = false;
  
  late bool _offeredCoffee;
  late bool _metTheOwner;
  late double _marketOutlook;
  List<String> _selectedBHKs = [];
  
  String? _finalDurationStr;

  @override
  void initState() {
    super.initState();
    _offeredCoffee = widget.source.offeredCoffee == 1;
    _metTheOwner = widget.source.metTheOwner == 1;
    _marketOutlook = (widget.source.marketOutlook ?? 0).toDouble();
    _selectedBHKs = widget.source.currentDemand?.split(',').where((s) => s.trim().isNotEmpty).toList() ?? [];
    
    if (widget.initialCalculatedMinutes != null) {
      _finalDurationStr = widget.durationStringGenerator(widget.initialCalculatedMinutes!);
    } else {
      _finalDurationStr = widget.source.visitDuration;
    }
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    
    try {
      // Sort BHKs numerically (e.g., 1 BHK, 2 BHK, 3 BHK, 4 BHK)
      final sortedBHKs = List<String>.from(_selectedBHKs);
      sortedBHKs.sort((a, b) {
        final aNum = int.tryParse(a.split(' ')[0]) ?? 0;
        final bNum = int.tryParse(b.split(' ')[0]) ?? 0;
        return aNum.compareTo(bNum);
      });

      final fieldsToUpdate = {
        'visit_duration': _finalDurationStr,
        'visit_status': 'Visit Done',
        'offered_coffee': _offeredCoffee ? 1 : 0,
        'met_the_owner': _metTheOwner ? 1 : 0,
        'market_outlook': _marketOutlook.toInt(),
        'current_demand': sortedBHKs.join(', '),
      };

      print('Questionnaire: Saving details for ${widget.source.name}');
      print('Questionnaire: Payload: $fieldsToUpdate');

      final result = await SourcingService.updateSourcingFields(widget.source.name!, fieldsToUpdate);
      if (result && mounted) {
        print('Questionnaire: Save successful');
        setState(() {
          widget.source.visitStatus = 'Visit Done';
          widget.source.docstatus = 1;
        });
        Navigator.pop(context);
        widget.onSaved();
        CustomSnackBar.show(context, message: 'Details saved successfully', isError: false, title: 'Notice');
      } else if (!result && mounted) {
        print('Questionnaire: Save failed on server');
        throw Exception("Failed to update on server. Check logs for details.");
      }
    } catch (e, stack) {
      print('Questionnaire: Catch error: $e');
      print('Questionnaire: Stack trace: $stack');
      if (mounted) {
        CustomSnackBar.show(context, message: 'Error saving: $e', isError: true, title: 'Error');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSwitchRow(String title, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: matteBlack),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: goldAccent,
          ),
        ],
      ),
    );
  }

  Color _getOutlookColor(double value) {
    if (value < 0) {
      return Color.lerp(Colors.redAccent, Colors.grey.shade400, (value + 5) / 5)!;
    } else {
      return Color.lerp(Colors.grey.shade400, const Color(0xFF4C6645), value / 5)!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sourcing Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: matteBlack, letterSpacing: -0.5),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_finalDurationStr != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: kBackgroundColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Visit Duration', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(_finalDurationStr!, style: const TextStyle(fontSize: 18, color: goldAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    const Text('Questionnaire', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: matteBlack)),
                    const SizedBox(height: 12),
                    
                    _buildSwitchRow('Did he offer coffee?', _offeredCoffee, (v) => setState(() => _offeredCoffee = v)),
                    _buildSwitchRow('Did you meet the owner?', _metTheOwner, (v) => setState(() => _metTheOwner = v)),
                    
                    const SizedBox(height: 24),
                    const Text('Market Outlook', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: matteBlack)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('-5', style: TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: _getOutlookColor(_marketOutlook),
                              thumbColor: _getOutlookColor(_marketOutlook),
                              overlayColor: _getOutlookColor(_marketOutlook).withOpacity(0.2),
                              valueIndicatorColor: _getOutlookColor(_marketOutlook),
                            ),
                            child: Slider(
                              value: _marketOutlook,
                              min: -5,
                              max: 5,
                              divisions: 10,
                              label: _marketOutlook.toInt().toString(),
                              onChanged: (v) => setState(() => _marketOutlook = v),
                            ),
                          ),
                        ),
                        const Text('5', style: TextStyle(fontSize: 12, color: Color(0xFF4C6645), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    const Text('Current Demand', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: matteBlack)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 8,
                      children: ['1 BHK', '2 BHK', '3 BHK', '4 BHK'].map((bhk) {
                        final isSelected = _selectedBHKs.contains(bhk);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedBHKs.remove(bhk);
                              } else {
                                _selectedBHKs.add(bhk);
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? goldAccent : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: goldAccent.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                              ] : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  bhk,
                                  style: TextStyle(
                                    color: isSelected ? goldAccent : matteBlack,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.check_circle, size: 16, color: goldAccent),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            
            // Bottom Save Button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: goldAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
