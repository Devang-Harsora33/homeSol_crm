import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Homesol/utils/custom_snackbar.dart';
import 'package:Homesol/models/sourcing.dart';
import 'package:Homesol/models/channel_partner.dart';
import 'package:Homesol/services/apis/sourcing/sourcing_service.dart';
import 'package:Homesol/services/apis/channel_partners/channel_partner.dart';
import 'package:Homesol/services/auth_service.dart';
import 'package:Homesol/services/location_service.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Homesol/services/notification_service.dart';
import 'package:Homesol/models/cp_campaign.dart';
import 'package:Homesol/services/apis/projects/cp_campaign_service.dart';
import 'package:Homesol/components/sourcing_questionnaire_popup.dart';
import 'package:Homesol/pages/channel_partner/channel_partner_creation_page.dart';

// ─── EXTENSION ───
extension FirstWhereOrNullExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

const Color goldAccent = Color(0xFF675D40);
const String _sourcingDraftKey = 'sourcing_creation_draft';
const Color matteBlack = Color(0xFF1A1A1A);
const Color offWhite = Color(0xFFF9F9F9);
const Color kBackgroundColor = Color(0xFFF2F2F7);

final kInputDecoration = InputDecoration(
  filled: true,
  fillColor: Colors.white,
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
  border: OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: Colors.grey.shade200),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: Colors.grey.shade200),
  ),
  focusedBorder: const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: goldAccent, width: 2),
  ),
  errorBorder: const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: Colors.redAccent),
  ),
);

class SourcingCreatePage extends StatefulWidget {
  final Sourcing? existingSourcing;
  final ChannelPartner? initialChannelPartner;

  const SourcingCreatePage({super.key, this.existingSourcing, this.initialChannelPartner});

  @override
  State<SourcingCreatePage> createState() => _SourcingCreatePageState();
}

class _SourcingCreatePageState extends State<SourcingCreatePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  Timer? _debounceTimer;

  final TextEditingController _contactPersonController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _cpSearchController = TextEditingController();
  final TextEditingController _cpDisplayController = TextEditingController();
  
  // Campaign controllers
  final TextEditingController _campaignDisplayController = TextEditingController();
  final TextEditingController _campaignSearchController = TextEditingController();

  String _visitStatus = 'Visit Scheduled';
  String _visitType = 'Open';
  String _cpInterest = 'Interested';
  double _visitDuration = 15.0; // Minutes
  DateTime _visitDate = DateTime.now();
  DateTime _nextFollowUpDate = DateTime.now().add(const Duration(days: 7));
  List<String> _selectedProjectIds = [];

  List<ChannelPartner> _channelPartners = [];
  ChannelPartner? _selectedCP;
  List<ContactPerson> _cpTeamMembers = [];
  ContactPerson? _selectedTeamMember;
  List<Map<String, dynamic>> _projects = [];
  
  List<CPCampaign> _campaigns = [];
  CPCampaign? _selectedCampaign;

  @override
  void initState() {
    super.initState();
    _initData();
    _mobileController.addListener(() {
      _checkPreviousVisits();
      _saveDraft();
    });
    _contactPersonController.addListener(_saveDraft);
    _whatsappController.addListener(_saveDraft);
    _remarkController.addListener(_saveDraft);
    _addressController.addListener(_saveDraft);
    _locationController.addListener(_saveDraft);
  }

  String _calculateDurationString(int minutes) {
    if (minutes < 60) return '$minutes mins';
    final hours = minutes ~/ 60;
    final remainingMins = minutes % 60;
    if (remainingMins == 0) {
      return '$hours Hour${hours > 1 ? 's' : ''}';
    }
    return '$hours Hour${hours > 1 ? 's' : ''} and $remainingMins mins';
  }

  Future<void> _showAutoOpenBottomSheet(Sourcing source, int minutes) async {
    bool cancelled = false;
    bool isFinished = false;

    await showModalBottomSheet(
      context: context,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext bContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 5.0, end: 0.0),
              duration: const Duration(seconds: 5),
              onEnd: () {
                if (!cancelled) {
                  isFinished = true;
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                  _showQuestionnairePopup(source, minutes);
                }
              },
              builder: (context, value, child) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Icon(Icons.timer_outlined, size: 48, color: goldAccent),
                      const SizedBox(height: 16),
                      const Text(
                        'Meeting Recorded!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: matteBlack,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Duration: ${_calculateDurationString(minutes)}.',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Opening Questionnaire in ${value.ceil()}s...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: goldAccent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: value / 5.0,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(goldAccent),
                        borderRadius: BorderRadius.circular(8),
                        minHeight: 8,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () {
                            cancelled = true;
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'CANCEL',
                            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ).then((_) {
      if (!cancelled && !isFinished) {
        cancelled = true;
      }
    });
  }

  void _showQuestionnairePopup(Sourcing source, [int? calculatedMinutes]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SourcingQuestionnairePopup(
        source: source,
        initialCalculatedMinutes: calculatedMinutes,
        durationStringGenerator: _calculateDurationString,
        onSaved: () {
          // No-op for now as we are popping the page anyway
        },
      ),
    );
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    try {
      final partners = await ChannelPartnerService.fetchAllChannelPartners();
      final projects = await ProjectService.fetchApiProjects();
      final campaigns = await CPCampaignService.fetchCPCampaigns();
      
      _channelPartners = partners;
      _projects = projects;
      _campaigns = campaigns;

      if (widget.existingSourcing != null) {
        await _applyExistingSourcing(widget.existingSourcing!);
      } else {
        if (widget.initialChannelPartner != null) {
          final matchedCP = _channelPartners.firstWhereOrNull((p) => p.name == widget.initialChannelPartner!.name);
          _onCPSelected(matchedCP ?? widget.initialChannelPartner!);
        } else {
          await _applyDraft();
        }
        _fetchCurrentLocation();
      }
    } catch (e) {
      debugPrint('Error in initData: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _applyExistingSourcing(Sourcing s) async {
    if (s.campaignDiscussed != null) {
      _selectedCampaign = _campaigns.firstWhereOrNull((c) => c.name == s.campaignDiscussed);
      _campaignDisplayController.text = _selectedCampaign?.campaignType ?? s.campaignDiscussed!;
    }
    
    final cpId = s.channelPartnerId;
    if (cpId != null) {
      _selectedCP = _channelPartners.firstWhereOrNull((p) => p.name == cpId);
      if (_selectedCP != null) {
        _cpDisplayController.text = _selectedCP!.firmName ?? '';
        _cpTeamMembers = _selectedCP!.contactPersons ?? [];
      }
    }

    _contactPersonController.text = s.contactPersonMet ?? '';
    _mobileController.text = s.mobileNumber ?? '';
    _whatsappController.text = s.whatsappNumber ?? '';
    _remarkController.text = s.remark ?? '';
    _addressController.text = s.address ?? '';
    _locationController.text = s.location ?? '';
    _visitStatus = _getValidVisitStatus(s.visitStatus);
    _visitType = s.visitType ?? 'Open';
    _cpInterest = s.cpInterest ?? 'Interested';
    
    if (s.interestedProject != null) {
      _selectedProjectIds = s.interestedProject!
          .map((ip) => ip.project)
          .where((id) => id != null)
          .cast<String>()
          .toList();
    }

    if (s.visitDate != null) {
      _visitDate = DateTime.tryParse(s.visitDate!) ?? DateTime.now();
    }
    if (s.nextFollowUp != null) {
      _nextFollowUpDate = DateTime.tryParse(s.nextFollowUp!) ?? DateTime.now().add(const Duration(days: 7));
    }
  }

  String _getValidVisitStatus(String? status) {
    if (status == 'Visit Scheduled') return 'Visit Scheduled';
    if (status == 'Visit Done') return 'Visit Done';
    if (status == 'Revisit Scheduled' || status == 'Scheduled' || status == 'Rescheduled') return 'Visit Scheduled';
    return 'Visit Done';
  }

  Future<void> _applyDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftString = prefs.getString(_sourcingDraftKey);
      if (draftString != null) {
        final Map<String, dynamic> draftData = json.decode(draftString);
        
        _contactPersonController.text = draftData['contact_person'] ?? '';
        _mobileController.text = draftData['mobile_no'] ?? '';
        _whatsappController.text = draftData['whatsapp_no'] ?? '';
        _remarkController.text = draftData['remark'] ?? '';
        _addressController.text = draftData['address'] ?? '';
        _locationController.text = draftData['location'] ?? '';
        _visitStatus = _getValidVisitStatus(draftData['visit_status']);
        _visitType = draftData['visit_type'] ?? 'Open';
        _cpInterest = draftData['cp_interest'] ?? 'Interested';
        
        if (draftData['visit_date'] != null) {
          _visitDate = DateTime.tryParse(draftData['visit_date']) ?? DateTime.now();
        }
        if (draftData['next_follow_up_date'] != null) {
          _nextFollowUpDate = DateTime.tryParse(draftData['next_follow_up_date']) ?? DateTime.now().add(const Duration(days: 7));
        }

        final dProjs = draftData['interested_projects'];
        if (dProjs != null && dProjs is List) {
          _selectedProjectIds = List<String>.from(dProjs);
        }

        final cpId = draftData['selected_cp_id'];
        if (cpId != null) {
          _selectedCP = _channelPartners.firstWhereOrNull((c) => c.name == cpId);
          if (_selectedCP != null) {
            _cpDisplayController.text = _selectedCP!.firmName ?? '';
            _cpTeamMembers = _selectedCP!.contactPersons ?? [];
            
            final teamId = draftData['selected_team_member_id'];
            if (teamId != null) {
              _selectedTeamMember = _cpTeamMembers.firstWhereOrNull((m) => m.name == teamId);
            }
          }
        }

        final campaignId = draftData['campaign_discussed'];
        if (campaignId != null) {
          _selectedCampaign = _campaigns.firstWhereOrNull((c) => c.name == campaignId);
          _campaignDisplayController.text = _selectedCampaign?.campaignType ?? '';
        }
      }
    } catch (e) {
      debugPrint('Error applying draft: $e');
    }
  }

  void _saveDraft({bool immediate = false}) {
    if (widget.existingSourcing != null) return;

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    Future<void> performSave() async {
      try {
        if (!mounted && !immediate) return;

        final prefs = await SharedPreferences.getInstance();
        
        final draftData = {
          'contact_person': _contactPersonController.text,
          'mobile_no': _mobileController.text,
          'whatsapp_no': _whatsappController.text,
          'remark': _remarkController.text,
          'address': _addressController.text,
          'location': _locationController.text,
          'visit_status': _visitStatus,
          'visit_type': _visitType,
          'cp_interest': _cpInterest,
          'visit_date': _visitDate.toIso8601String(),
          'next_follow_up_date': _nextFollowUpDate.toIso8601String(),
          'interested_projects': _selectedProjectIds,
          'selected_cp_id': _selectedCP?.name,
          'selected_team_member_id': _selectedTeamMember?.name,
          'campaign_discussed': _selectedCampaign?.name,
        };
        await prefs.setString(_sourcingDraftKey, json.encode(draftData));
      } catch (e) {
        debugPrint('Error saving sourcing draft: $e');
      }
    }

    if (immediate) {
      performSave();
    } else {
      _debounceTimer = Timer(const Duration(milliseconds: 500), performSave);
    }
  }

  Future<void> _clearDraft() async {
    try {
      if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sourcingDraftKey);
    } catch (e) {
      debugPrint('Error clearing sourcing draft: $e');
    }
  }

  Future<void> _resetForm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: goldAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.refresh_rounded, color: goldAccent, size: 32),
              ),
              const SizedBox(height: 16),
              const Text('Reset Form?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('This will clear all entered data and delete your saved draft.', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Reset', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await _clearDraft();
      setState(() {
        _contactPersonController.clear();
        _mobileController.clear();
        _whatsappController.clear();
        _remarkController.clear();
        _addressController.clear();
        _locationController.clear();
        _campaignDisplayController.clear();
        _visitStatus = 'Visit Scheduled';
        _visitType = 'Open';
        _cpInterest = 'Interested';
        _visitDate = DateTime.now();
        _nextFollowUpDate = DateTime.now().add(const Duration(days: 7));
        _selectedProjectIds = [];
        _selectedCP = null;
        _selectedTeamMember = null;
        _selectedCampaign = null;
        _cpDisplayController.clear();
      });
      if (mounted) {
        CustomSnackBar.show(context, message: 'Form reset successfully');
      }
    }
  }

  void _showProjectPicker() {
    TextEditingController searchController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = searchController.text.toLowerCase();
            final filteredList = _projects.where((p) => (p['name'] ?? '').toLowerCase().contains(query)).toList();
            
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Interested Projects', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              if (_selectedProjectIds.length == _projects.length) {
                                _selectedProjectIds.clear();
                              } else {
                                _selectedProjectIds = _projects.map((p) => p['id']!.toString()).toList();
                              }
                            });
                            setState(() {});
                            _saveDraft();
                          },
                          child: Text(_selectedProjectIds.length == _projects.length ? 'Clear All' : 'Select All', 
                            style: const TextStyle(color: goldAccent, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: TextField(
                      controller: searchController,
                      onChanged: (v) => setModalState(() {}),
                      decoration: kInputDecoration.copyWith(
                        hintText: 'Search projects...',
                        prefixIcon: const Icon(Icons.search, color: goldAccent),
                        fillColor: Colors.grey[50],
                      ),
                    ),
                  ),
                  Expanded(
                    child: filteredList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.apartment_rounded, size: 64, color: Colors.grey[200]),
                              const SizedBox(height: 16),
                              Text('No projects found', style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            final p = filteredList[index];
                            final id = p['id']!;
                            final isSelected = _selectedProjectIds.contains(id);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: InkWell(
                                onTap: () {
                                  setModalState(() {
                                    if (isSelected) _selectedProjectIds.remove(id);
                                    else _selectedProjectIds.add(id);
                                  });
                                  setState(() {});
                                  _saveDraft();
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? goldAccent.withOpacity(0.05) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isSelected ? goldAccent.withOpacity(0.2) : Colors.transparent),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(p['name'] ?? '', 
                                          style: TextStyle(
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            color: isSelected ? matteBlack : Colors.grey[700],
                                          )),
                                      ),
                                      if (isSelected) 
                                        const Icon(Icons.check_circle_rounded, color: goldAccent, size: 22)
                                      else
                                        Icon(Icons.circle_outlined, color: Colors.grey[300], size: 22),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: matteBlack,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('CONFIRM SELECTION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _checkPreviousVisits() async {
    final number = _mobileController.text;
    if (number.length < 10 || widget.existingSourcing != null) return;

    try {
      final sources = await SourcingService.getMySources();
      final previousVisits = sources.where((s) => s.mobileNumber == number).toList();

      if (previousVisits.isNotEmpty) {
        previousVisits.sort((a, b) => (b.visitDate ?? '').compareTo(a.visitDate ?? ''));
        final lastVisit = previousVisits.first;
        
        if (lastVisit.visitDate != null) {
          final lastDate = DateTime.tryParse(lastVisit.visitDate!);
          if (lastDate != null) {
            final difference = DateTime.now().difference(lastDate).inDays;
            if (difference <= 60) {
            if (mounted) {
            setState(() {
            _visitStatus = 'Visit Scheduled';
            });
            }
            }
            }
            }
            }
            } catch (e) {
            debugPrint('Error checking previous visits: $e');
            }
            }

            Future<void> _selectNextFollowUpDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _nextFollowUpDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: goldAccent, onPrimary: Colors.white, onSurface: matteBlack),
        ),
        child: child!,
      ),
    );

    if (pickedDate != null) {
      if (!mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_nextFollowUpDate),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              dialBackgroundColor: Colors.grey[100],
            ),
            colorScheme: const ColorScheme.light(primary: goldAccent, onPrimary: Colors.white, onSurface: matteBlack),
          ),
          child: child!,
        ),
      );

      if (pickedTime != null) {
        setState(() {
          _nextFollowUpDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
        _saveDraft();
      }
    }
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final Position? position = await LocationService.instance.getCurrentLocation();
      if (position != null) {
        final locationJson = {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "properties": {"point_type": "marker"},
              "geometry": {
                "type": "Point",
                "coordinates": [position.longitude, position.latitude]
              }
            }
          ]
        };
        if (mounted) {
          setState(() {
            _locationController.text = jsonEncode(locationJson);
          });
        }
      }
    } catch (e) {
      debugPrint('Error auto-fetching location: $e');
    }
  }

  Future<void> _openInMaps() async {
    if (_locationController.text.isEmpty) return;
    try {
      final data = jsonDecode(_locationController.text);
      final coords = data['features'][0]['geometry']['coordinates'];
      final lon = coords[0];
      final lat = coords[1];
      final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      }
    } catch (e) {
      debugPrint('Error opening maps: $e');
    }
  }

  void _onCPSelected(ChannelPartner? cp) {
    setState(() {
      _selectedCP = cp;
      _cpDisplayController.text = cp?.firmName ?? '';
      _cpTeamMembers = cp?.contactPersons ?? [];
      _selectedTeamMember = null;
      
      if (_selectedCampaign != null && cp != null && _selectedCampaign!.channelPartner != cp.name) {
          _selectedCampaign = null;
          _campaignDisplayController.clear();
      }
      
      if (cp != null && cp.fullAddress != null) {
        _addressController.text = cp.fullAddress!;
      }
    });
    _saveDraft();
  }

  void _onTeamMemberSelected(ContactPerson? member) {
    setState(() {
      _selectedTeamMember = member;
      if (member != null) {
        _contactPersonController.text = member.fullName ?? 'No Name';
        _mobileController.text = member.mobile ?? '';
      }
    });
    _saveDraft();
  }

  void _showCPPicker() {
    _cpSearchController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredList = _channelPartners.where((cp) {
              final query = _cpSearchController.text.toLowerCase();
              final name = (cp.firmName ?? '').toLowerCase();
              final mobile = (cp.mobileNumber ?? '').toLowerCase();
              final email = (cp.email ?? '').toLowerCase();
              return name.contains(query) || mobile.contains(query) || email.contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _cpSearchController,
                      decoration: kInputDecoration.copyWith(
                        hintText: 'Search Channel Partner...',
                        prefixIcon: const Icon(Icons.search, color: goldAccent),
                      ),
                      onChanged: (val) => setModalState(() {}),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ChannelPartnerCreationPage()),
                        ).then((_) => _initData());
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: goldAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: goldAccent.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: goldAccent,
                              child: Icon(Icons.add, size: 18, color: Colors.white),
                            ),
                            SizedBox(width: 16),
                            Text(
                              'Can\'t find partner? ',
                              style: TextStyle(fontSize: 14, color: Colors.black54),
                            ),
                            Text(
                              'Add New',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: goldAccent,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredList.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final cp = filteredList[index];
                        return ListTile(
                          title: Text(cp.firmName ?? 'No Name'),
                          subtitle: Text(cp.mobileNumber ?? cp.email ?? ''),
                          onTap: () {
                            _onCPSelected(cp);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCampaignPicker() {
    if (_selectedCP == null) {
      CustomSnackBar.show(context, message: 'Please select a Channel Partner first', isError: true);
      return;
    }

    _campaignSearchController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = _campaignSearchController.text.toLowerCase();
            final filteredList = _campaigns.where((c) {
              final matchesCP = c.channelPartner == _selectedCP!.name;
              final matchesQuery = c.campaignType.toLowerCase().contains(query) || 
                                  c.project.toLowerCase().contains(query);
              return matchesCP && matchesQuery;
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Select Campaign', 
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _campaignSearchController,
                      decoration: kInputDecoration.copyWith(
                        hintText: 'Search campaign type...',
                        prefixIcon: const Icon(Icons.search, color: goldAccent),
                      ),
                      onChanged: (val) => setModalState(() {}),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline, color: goldAccent),
                    title: const Text('Create New Campaign', style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(context);
                      _showCreateCampaignPopup();
                    },
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: filteredList.isEmpty
                        ? const Center(child: Text('No campaigns found for this CP'))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredList.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final c = filteredList[index];
                              final projectName = _projects.firstWhereOrNull((p) => p['id'] == c.project)?['name'] ?? c.project;
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                title: Text(c.campaignType, style: const TextStyle(fontWeight: FontWeight.bold, color: matteBlack)),
                                subtitle: Text('Project: $projectName'),
                                onTap: () {
                                  setState(() {
                                    _selectedCampaign = c;
                                    _campaignDisplayController.text = c.campaignType;
                                  });
                                  _saveDraft();
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCreateCampaignPopup() {
    if (_selectedCP == null) {
      CustomSnackBar.show(context, message: 'Please select a Channel Partner first', isError: true);
      return;
    }

    String? localCampaignType = 'NoBrokerHood';
    String localStatus = 'Active';
    DateTime startDate = DateTime.now();
    String? localProject = _selectedProjectIds.isNotEmpty ? _selectedProjectIds.first : null;
    bool isSaving = false;

    final List<String> campaignTypes = [
      'NoBrokerHood',
      'MagicBricks',
      '99Acres',
      'Meta Ads',
      'Google Search Ads',
      'Youtube Ads',
      'SquareYards',
      'WhatsApp Broadcast',
      'Bulk SMS'
    ];

    final List<String> statusOptions = ['Active', 'Inactive'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: goldAccent.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.campaign_outlined, color: goldAccent, size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Text('New CP Campaign', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: matteBlack)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('For: ${_selectedCP!.firmName}', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 28),
                  
                  DropdownButtonFormField<String>(
                    value: localProject,
                    dropdownColor: Colors.white,
                    decoration: kInputDecoration.copyWith(
                      labelText: 'Project *',
                      prefixIcon: const Icon(Icons.apartment_rounded, color: goldAccent, size: 20),
                    ),
                    items: _projects.map((p) => DropdownMenuItem(value: p['id']!.toString(), child: Text(p['name']?.toString() ?? '', style: const TextStyle(fontSize: 14)))).toList(),
                    onChanged: (v) => setDialogState(() => localProject = v),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: localCampaignType,
                    dropdownColor: Colors.white,
                    decoration: kInputDecoration.copyWith(
                      labelText: 'Campaign Type *',
                      prefixIcon: const Icon(Icons.category_outlined, color: goldAccent, size: 20),
                    ),
                    items: campaignTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 14)))).toList(),
                    onChanged: (v) => setDialogState(() => localCampaignType = v),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: localStatus,
                    dropdownColor: Colors.white,
                    decoration: kInputDecoration.copyWith(
                      labelText: 'Status *',
                      prefixIcon: const Icon(Icons.info_outline_rounded, color: goldAccent, size: 20),
                    ),
                    items: statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14)))).toList(),
                    onChanged: (v) => setDialogState(() => localStatus = v!),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context, 
                        initialDate: startDate, 
                        firstDate: DateTime(2000), 
                        lastDate: DateTime(2101),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: goldAccent, onPrimary: Colors.white, onSurface: matteBlack)),
                          child: child!,
                        ),
                      );
                      if (pickedDate != null) {
                        if (!context.mounted) return;
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(startDate),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              timePickerTheme: TimePickerThemeData(
                                backgroundColor: Colors.white,
                                dialBackgroundColor: Colors.grey[100],
                              ),
                              colorScheme: const ColorScheme.light(primary: goldAccent, onPrimary: Colors.white, onSurface: matteBlack),
                            ),
                            child: child!,
                          ),
                        );
                        if (pickedTime != null) {
                          setDialogState(() {
                            startDate = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        }
                      }
                    },
                    child: InputDecorator(
                      decoration: kInputDecoration.copyWith(
                        labelText: 'Start Date & Time',
                        prefixIcon: const Icon(Icons.calendar_today_rounded, color: goldAccent, size: 20),
                      ),
                      child: Text(DateFormat('dd MMM yyyy, hh:mm a').format(startDate), style: const TextStyle(fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          child: Text('Cancel', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSaving ? null : () async {
                            if (localProject == null || localCampaignType == null) {
                              CustomSnackBar.show(context, message: 'Please fill all required fields', isError: true);
                              return;
                            }
                            setDialogState(() => isSaving = true);
                            final newCampaign = await CPCampaignService.createCPCampaign({
                              'channel_partner': _selectedCP!.name,
                              'project': localProject,
                              'campaign_type': localCampaignType,
                              'start_date': DateFormat('yyyy-MM-dd HH:mm:ss').format(startDate),
                              'status': localStatus,
                            });
                            if (newCampaign != null) {
                              final allCampaigns = await CPCampaignService.fetchCPCampaigns();
                              if (mounted) {
                                setState(() {
                                  _campaigns = allCampaigns;
                                  _selectedCampaign = newCampaign;
                                  _campaignDisplayController.text = newCampaign.campaignType;
                                });
                                _saveDraft();
                                Navigator.pop(context);
                                CustomSnackBar.show(context, message: 'Campaign created successfully');
                              }
                            } else {
                              setDialogState(() => isSaving = false);
                              CustomSnackBar.show(context, message: 'Creation failed', isError: true);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: matteBlack,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: isSaving 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                            : const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _contactPersonController.dispose();
    _mobileController.dispose();
    _whatsappController.dispose();
    _remarkController.dispose();
    _addressController.dispose();
    _locationController.dispose();
    _cpSearchController.dispose();
    _cpDisplayController.dispose();
    _campaignDisplayController.dispose();
    _campaignSearchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: goldAccent, onPrimary: Colors.white, onSurface: matteBlack)),
        child: child!,
      ),
    );

    if (pickedDate != null) {
      if (!mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_visitDate),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              dialBackgroundColor: Colors.grey[100],
            ),
            colorScheme: const ColorScheme.light(primary: goldAccent, onPrimary: Colors.white, onSurface: matteBlack),
          ),
          child: child!,
        ),
      );

      if (pickedTime != null) {
        setState(() {
          _visitDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
        });
        _saveDraft();
      }
    }
  }

  String _getCoordinatesDisplay() {
    if (_locationController.text.isEmpty) return 'Not captured';
    try {
      final data = jsonDecode(_locationController.text);
      final coords = data['features'][0]['geometry']['coordinates'];
      return '${coords[1].toStringAsFixed(6)}, ${coords[0].toStringAsFixed(6)}';
    } catch (e) { return 'Invalid'; }
  }

  Future<Map<String, dynamic>?> _showOtpDialog(Map<String, dynamic>? triggerResponse) async {
    String otp = '';
    bool isVerifying = false;
    String? debugOtp;
    try {
      if (triggerResponse != null && triggerResponse.containsKey('_server_messages')) {
        final List<dynamic> serverMessages = jsonDecode(triggerResponse['_server_messages']);
        if (serverMessages.isNotEmpty) {
          final Map<String, dynamic> firstMsg = jsonDecode(serverMessages[0]);
          final otpMatch = RegExp(r'OTP: <b>(\d+)</b>').firstMatch(firstMsg['message'] ?? '');
          if (otpMatch != null) debugOtp = otpMatch.group(1);
        }
      }
    } catch (_) {}

    return showGeneralDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'OTP',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: ScaleTransition(
            scale: anim1,
            child: StatefulBuilder(
              builder: (context, setDialogState) => Dialog(
                backgroundColor: Colors.white.withOpacity(0.9),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: goldAccent.withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.lock_person_outlined, color: goldAccent, size: 36),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'OTP Verification',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: matteBlack, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 12),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
                            children: [
                              const TextSpan(text: 'Enter the 4-digit code sent to\n'),
                              TextSpan(
                                text: _mobileController.text,
                                style: const TextStyle(color: matteBlack, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: 0.0,
                              child: TextField(
                                autofocus: true,
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                                onChanged: (value) => setDialogState(() => otp = value),
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(4, (index) {
                                bool isFilled = otp.length > index;
                                return Container(
                                  width: 50,
                                  height: 60,
                                  margin: const EdgeInsets.symmetric(horizontal: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isFilled ? goldAccent : Colors.grey.shade200,
                                      width: isFilled ? 2.5 : 1,
                                    ),
                                    boxShadow: isFilled ? [
                                      BoxShadow(
                                        color: goldAccent.withOpacity(0.15),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      )
                                    ] : [],
                                  ),
                                  child: Center(
                                    child: Text(
                                      isFilled ? otp[index] : '',
                                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: matteBlack),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                        
                        if (debugOtp != null) 
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: InkWell(
                              onTap: () => Clipboard.setData(ClipboardData(text: debugOtp!)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: matteBlack,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('DEBUG CODE: $debugOtp', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                              ),
                            ),
                          ),
                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: ElevatedButton(
                            onPressed: (isVerifying || otp.length != 4) ? null : () async {
                              setDialogState(() => isVerifying = true);
                              final success = await SourcingService.verifyOtp(_mobileController.text, otp);
                              if (success && context.mounted) {
                                Navigator.pop(context, {'verified': true, 'otp': otp});
                              } else if (context.mounted) {
                                CustomSnackBar.show(context, message: 'Invalid Verification Code', isError: true);
                              }
                              setDialogState(() => isVerifying = false);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: matteBlack,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade200,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              elevation: 0,
                            ),
                            child: isVerifying 
                              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) 
                              : const Text('VERIFY & PROCEED', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: isVerifying ? null : () => Navigator.pop(context),
                          child: Text('Cancel', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    String? enteredOtp;
    int isVerified = 0;

    if (widget.existingSourcing == null) {
      final trigger = await SourcingService.triggerOtp(_mobileController.text);
      if (trigger == null) {
        setState(() => _isLoading = false);
        if (mounted) CustomSnackBar.show(context, message: 'OTP failed', isError: true);
        return;
      }
      final otpResult = await _showOtpDialog(trigger);
      if (otpResult == null || otpResult['verified'] != true) {
        setState(() => _isLoading = false);
        return;
      }
      enteredOtp = otpResult['otp'];
      isVerified = 1;
    }

    final sourcing = Sourcing(
      name: widget.existingSourcing?.name,
      salesPartner: _selectedCP?.name,
      contactPersonMet: _contactPersonController.text,
      mobileNumber: _mobileController.text,
      whatsappNumber: _whatsappController.text,
      visitStatus: _visitStatus,
      visitDate: DateFormat('yyyy-MM-dd HH:mm:ss').format(_visitDate),
      nextFollowUp: DateFormat('yyyy-MM-dd HH:mm:ss').format(_nextFollowUpDate),
      interestedProject: _selectedProjectIds.map((id) => SourcingProject(project: id)).toList(),
      remark: _remarkController.text,
      address: _addressController.text,
      location: _locationController.text,
      visitType: _visitType,
      cpInterest: _cpInterest,
      campaignDiscussed: _selectedCampaign?.name,
      enterOtp: enteredOtp,
      isVerified: isVerified,
      offeredCoffee: widget.existingSourcing?.offeredCoffee,
      metTheOwner: widget.existingSourcing?.metTheOwner,
      marketOutlook: widget.existingSourcing?.marketOutlook,
      currentDemand: widget.existingSourcing?.currentDemand,
      visitDuration: _visitStatus == 'Visit Done' ? '${_visitDuration.toInt()} mins' : widget.existingSourcing?.visitDuration,
    );

    try {
      if (_locationController.text.isNotEmpty && _selectedProjectIds.isNotEmpty) {
        final locData = jsonDecode(_locationController.text);
        final coords = locData['features'][0]['geometry']['coordinates'];
        final sfsLng = double.tryParse(coords[0].toString()) ?? 0.0;
        final sfsLat = double.tryParse(coords[1].toString()) ?? 0.0;
        
        final projectLocationsList = await ProjectService.fetchProjectLocations();
        final Map<String, Map<String, double>> projectLocations = {};
        for (var p in projectLocationsList) {
          final id = p['project_id'].toString();
          final plat = double.tryParse(p['latitude']?.toString() ?? '0') ?? 0.0;
          final plng = double.tryParse(p['longitude']?.toString() ?? '0') ?? 0.0;
          projectLocations[id] = {'lat': plat, 'lng': plng};
        }

        for (final projectId in _selectedProjectIds) {
          final pLoc = projectLocations[projectId];
          if (pLoc != null) {
            final distanceKm = LocationService.instance.calculateDistance(sfsLat, sfsLng, pLoc['lat']!, pLoc['lng']!);
            final distanceMeters = distanceKm * 1000;
            final type = distanceMeters < 300 ? 'IBM' : 'OBM';
            print('--- SOURCING LOCATION DEBUG ---');
            print('Project: $projectId');
            print('Sourcing Lat/Lng: $sfsLat, $sfsLng');
            print('Project Lat/Lng: ${pLoc['lat']}, ${pLoc['lng']}');
            print('Distance: ${distanceMeters.toStringAsFixed(2)} meters ($type)');
            print('-------------------------------');
          } else {
            print('--- SOURCING LOCATION DEBUG ---');
            print('Project: $projectId - Location not found (OBM)');
            print('-------------------------------');
          }
        }
      }
    } catch (e) {
      print('--- SOURCING LOCATION DEBUG ERROR: $e ---');
    }

    final result = widget.existingSourcing == null ? await SourcingService.createSourcing(sourcing) : await SourcingService.updateSourcing(sourcing);
    
    if (result != null && _visitStatus == 'Visit Done') {
      // Direct submission
      await SourcingService.updateDocStatus(result.name!, 1);
      // Update the local result object status so the questionnaire gets the correct info
      result.docstatus = 1;
    }

    setState(() => _isLoading = false);

    if (result != null) {
      await _clearDraft();
      if (mounted) {
        if (_visitStatus == 'Visit Done') {
          // Pass the result and minutes back to SourcingListPage to handle the workflow
          Navigator.pop(context, {
            'refresh': true,
            'openQuestionnaire': true,
            'sourcing': result,
            'minutes': _visitDuration.toInt(),
          });
        } else {
          CustomSnackBar.show(context, message: 'Saved successfully');
          Navigator.pop(context, true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && widget.existingSourcing == null && result != true) {
          _saveDraft(immediate: true);
        }
      },
      child: Scaffold(
        backgroundColor: kBackgroundColor,
        appBar: AppBar(
          title: Text(widget.existingSourcing == null ? 'Create Sourcing' : 'Edit Sourcing', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: matteBlack,
          centerTitle: true,
          actions: [if (widget.existingSourcing == null) IconButton(onPressed: _resetForm, icon: const Icon(Icons.refresh, color: Colors.red))],
        ),
        body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: goldAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildSectionHeader('Channel Partner'),
                    _buildFormCard([
                      TextFormField(
                        controller: _cpDisplayController,
                        readOnly: true,
                        decoration: kInputDecoration.copyWith(
                          labelText: 'Channel Partner', 
                          suffixIcon: const Icon(Icons.arrow_drop_down, color: goldAccent),
                          prefixIcon: const Icon(Icons.business_rounded, color: goldAccent, size: 20),
                        ),
                        onTap: _showCPPicker,
                        validator: (v) => _selectedCP == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _campaignDisplayController,
                        readOnly: true,
                        decoration: kInputDecoration.copyWith(
                          labelText: 'Campaign Ran By CP', 
                          suffixIcon: const Icon(Icons.arrow_drop_down, color: goldAccent),
                          prefixIcon: const Icon(Icons.campaign_outlined, color: goldAccent, size: 20),
                        ),
                        onTap: _showCampaignPicker,
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Contact Information'),
                    _buildFormCard([
                      if (_cpTeamMembers.isNotEmpty)
                        DropdownButtonFormField<ContactPerson>(
                          value: _selectedTeamMember,
                          dropdownColor: Colors.white,
                          decoration: kInputDecoration.copyWith(
                            labelText: 'Contact Person Met',
                            prefixIcon: const Icon(Icons.person_outline, color: goldAccent, size: 20),
                          ),
                          items: _cpTeamMembers.map((m) => DropdownMenuItem(value: m, child: Text(m.fullName ?? '', style: const TextStyle(fontSize: 14)))).toList(),
                          onChanged: _onTeamMemberSelected,
                          validator: (v) => v == null ? 'Required' : null,
                        )
                      else
                        TextFormField(
                          controller: _contactPersonController,
                          decoration: kInputDecoration.copyWith(
                            labelText: 'Contact Person Met',
                            prefixIcon: const Icon(Icons.person_outline, color: goldAccent, size: 20),
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _mobileController,
                        decoration: kInputDecoration.copyWith(
                          labelText: 'Mobile Number',
                          prefixIcon: const Icon(Icons.phone_android_rounded, color: goldAccent, size: 20),
                        ),
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) => (v == null || v.length != 10) ? '10 digits required' : null,
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Visit Details'),
                    _buildFormCard([
                      DropdownButtonFormField<String>(
                        value: _visitStatus,
                        dropdownColor: Colors.white,
                        decoration: kInputDecoration.copyWith(
                          labelText: 'Visit Status',
                          prefixIcon: const Icon(Icons.info_outline_rounded, color: goldAccent, size: 20),
                        ),
                        items: ['Visit Done', 'Visit Scheduled'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14)))).toList(),
                        onChanged: (v) => setState(() => _visitStatus = v!),
                      ),
                      if (_visitStatus == 'Visit Done') ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: goldAccent.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: goldAccent.withOpacity(0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.timer_outlined, color: goldAccent, size: 18),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Meeting Duration',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: matteBlack,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: goldAccent,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _calculateDurationString(_visitDuration.toInt()),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: goldAccent,
                                  inactiveTrackColor: goldAccent.withOpacity(0.1),
                                  thumbColor: goldAccent,
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                                  overlayColor: goldAccent.withOpacity(0.1),
                                  valueIndicatorColor: goldAccent,
                                  valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                                ),
                                child: Slider(
                                  value: _visitDuration,
                                  min: 0,
                                  max: 60,
                                  divisions: 60,
                                  label: '${_visitDuration.toInt()} mins',
                                  onChanged: (v) => setState(() => _visitDuration = v),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('0 min', style: TextStyle(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.w500)),
                                    Text('1 hr', style: TextStyle(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_visitStatus == 'Visit Scheduled') ...[
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: _selectDate,
                          child: InputDecorator(
                            decoration: kInputDecoration.copyWith(
                              labelText: 'Visit Date & Time',
                              prefixIcon: const Icon(Icons.calendar_month_rounded, color: goldAccent, size: 20),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('dd MMM yyyy, hh:mm a').format(_visitDate),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: matteBlack),
                                ),
                                const Icon(Icons.edit_calendar_rounded, size: 18, color: goldAccent),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FormField<List<String>>(
                        initialValue: _selectedProjectIds,
                        validator: (v) => _selectedProjectIds.isEmpty ? 'At least one project required' : null,
                        builder: (state) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: _showProjectPicker,
                                child: InputDecorator(
                                  decoration: kInputDecoration.copyWith(
                                    labelText: 'Interested Projects',
                                    prefixIcon: const Icon(Icons.apartment_rounded, color: goldAccent, size: 20),
                                    suffixIcon: const Icon(Icons.add_circle_outline, color: goldAccent),
                                    errorText: state.hasError ? state.errorText : null,
                                  ),
                                  child: _selectedProjectIds.isEmpty
                                      ? Text('Tap to select projects', style: TextStyle(color: Colors.grey[400], fontSize: 14))
                                      : const Text('Add more projects...', style: TextStyle(color: goldAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              if (_selectedProjectIds.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: _selectedProjectIds.map((id) {
                                    final projectName = _projects.firstWhereOrNull((p) => p['id'] == id)?['name'] ?? id;
                                    return Chip(
                                      label: Text(projectName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: matteBlack)),
                                      onDeleted: () {
                                        setState(() {
                                          _selectedProjectIds.remove(id);
                                          state.didChange(_selectedProjectIds);
                                        });
                                        _saveDraft();
                                      },
                                      deleteIcon: const Icon(Icons.cancel, size: 16, color: goldAccent),
                                      backgroundColor: goldAccent.withOpacity(0.08),
                                      side: BorderSide(color: goldAccent.withOpacity(0.2)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _selectNextFollowUpDateTime,
                        child: InputDecorator(
                          decoration: kInputDecoration.copyWith(
                            labelText: 'Next Follow-up',
                            prefixIcon: const Icon(Icons.notification_important_outlined, color: goldAccent, size: 20),
                          ),
                          child: Text(DateFormat('dd MMM yyyy, hh:mm a').format(_nextFollowUpDate), style: const TextStyle(fontSize: 15)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _remarkController, 
                        decoration: kInputDecoration.copyWith(
                          labelText: 'Remark',
                          prefixIcon: const Icon(Icons.notes_rounded, color: goldAccent, size: 20),
                        ), 
                        maxLines: null,
                        minLines: 3,
                        keyboardType: TextInputType.multiline,
                      ),
                    ]),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: matteBlack,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: const Text('SAVE SOURCING', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity, 
      padding: const EdgeInsets.only(left: 4, bottom: 8), 
      child: Text(title.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.1))
    );
  }

  Widget _buildFormCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20), 
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children
      )
    );
  }
}
