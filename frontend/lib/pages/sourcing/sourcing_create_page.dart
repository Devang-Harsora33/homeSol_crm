import 'package:flutter/material.dart';
import 'package:Homesol/models/sourcing.dart';
import 'package:Homesol/models/channel_partner.dart';
import 'package:Homesol/services/apis/sourcing/sourcing_service.dart';
import 'package:Homesol/services/apis/channel_partners/channel_partner.dart';
import 'package:Homesol/services/auth_service.dart';
import 'package:Homesol/services/location_service.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

const Color goldAccent = Color(0xFF675D40);
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
  bool _isLoading = false;

  final TextEditingController _contactPersonController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _cpSearchController = TextEditingController();
  final TextEditingController _cpDisplayController = TextEditingController();
  
  String _visitStatus = 'Visit Done';
  String _visitType = 'Open';
  String _cpInterest = 'Interested';
  DateTime _visitDate = DateTime.now();
  DateTime _nextFollowUpDate = DateTime.now().add(const Duration(days: 7));
  String? _interestedProject;
  
  bool _digital = false;
  bool _reference = false;
  bool _dataCalling = false;
  bool _retail = false;
  bool _underConstruction = false;
  bool _rental = false;
  bool _readyToMove = false;
  bool _callingSupport = false;
  bool _digitalKit = false;
  bool _standees = false;
  bool _smsBlast = false;
  bool _whatsappBlast = false;

  List<ChannelPartner> _channelPartners = [];
  ChannelPartner? _selectedCP;
  List<ContactPerson> _cpTeamMembers = [];
  ContactPerson? _selectedTeamMember;
  List<Map<String, String>> _projects = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _mobileController.addListener(_checkPreviousVisits);
  }

  Future<void> _checkPreviousVisits() async {
    final number = _mobileController.text;
    if (number.length < 10 || widget.existingSourcing != null) return;

    try {
      final sources = await SourcingService.getMySources();
      final previousVisits = sources.where((s) => s.mobileNumber == number).toList();

      if (previousVisits.isNotEmpty) {
        // Sort by date descending
        previousVisits.sort((a, b) => (b.visitDate ?? '').compareTo(a.visitDate ?? ''));
        final lastVisit = previousVisits.first;
        
        if (lastVisit.visitDate != null) {
          final lastDate = DateTime.tryParse(lastVisit.visitDate!);
          if (lastDate != null) {
            final difference = DateTime.now().difference(lastDate).inDays;
            if (difference <= 60) {
              if (mounted) {
                setState(() {
                  _visitStatus = 'Revisit Scheduled';
                });
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error checking previous visits: $e');
    }
  }

  Future<void> _selectNextFollowUpDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _nextFollowUpDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: goldAccent,
              onPrimary: Colors.white,
              onSurface: matteBlack,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      if (!mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_nextFollowUpDate),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: goldAccent,
                onPrimary: Colors.white,
                onSurface: matteBlack,
              ),
            ),
            child: child!,
          );
        },
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
      }
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final partners = await ChannelPartnerService.fetchAllChannelPartners();
      final projects = await ProjectService.fetchApiProjects();
      setState(() {
        _channelPartners = partners;
        _projects = projects;
      });

      if (widget.existingSourcing != null) {
        final s = widget.existingSourcing!;
        
        // Match Channel Partner
        final cpId = s.channelPartnerId;
        if (cpId != null) {
          final matchedCP = partners.where((p) => p.name == cpId).toList();
          if (matchedCP.isNotEmpty) {
            _selectedCP = matchedCP.first;
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
        _visitStatus = s.visitStatus ?? 'Visit Done';
        _visitType = s.visitType ?? 'Open';
        _cpInterest = s.cpInterest ?? 'Interested';
        _interestedProject = s.interestedProject;
        if (s.visitDate != null) {
          _visitDate = DateTime.tryParse(s.visitDate!) ?? DateTime.now();
        }
        if (s.nextFollowUp != null) {
          _nextFollowUpDate = DateTime.tryParse(s.nextFollowUp!) ?? DateTime.now().add(const Duration(days: 7));
        }
        _digital = s.digital == 1;
        _reference = s.reference == 1;
        _dataCalling = s.dataCalling == 1;
        _retail = s.retail == 1;
        _underConstruction = s.underConstruction == 1;
        _rental = s.rental == 1;
        _readyToMove = s.readyToMove == 1;
        _callingSupport = s.callingSupport == 1;
        _digitalKit = s.digitalKit == 1;
        _standees = s.standees == 1;
        _smsBlast = s.smsBlast == 1;
        _whatsappBlast = s.whatsappBlast == 1;
      } else {
        if (widget.initialChannelPartner != null) {
          final matchedCP = partners.where((p) => p.name == widget.initialChannelPartner!.name).toList();
          if (matchedCP.isNotEmpty) {
            _onCPSelected(matchedCP.first);
          } else {
            _onCPSelected(widget.initialChannelPartner!);
          }
        }
        _fetchCurrentLocation();
      }
    } finally {
      setState(() => _isLoading = false);
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
        setState(() {
          _locationController.text = jsonEncode(locationJson);
        });
      }
    } catch (e) {
      print('Error auto-fetching location: $e');
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
      print('Error opening maps: $e');
    }
  }

  void _onCPSelected(ChannelPartner? cp) {
    setState(() {
      _selectedCP = cp;
      _cpDisplayController.text = cp?.firmName ?? '';
      _cpTeamMembers = cp?.contactPersons ?? [];
      _selectedTeamMember = null;
      
      if (cp != null) {
        _digital = cp.isDigital == 1;
        _reference = cp.isReference == 1;
        _dataCalling = cp.isDataCalling == 1;
        _retail = cp.isRetail == 1;
        _underConstruction = cp.isUnderConstruction == 1;
        _rental = cp.isRental == 1;
        _readyToMove = cp.isReadyToMove == 1;
        _callingSupport = cp.reqCallingSupport == 1;
        _digitalKit = cp.reqDigitalKit == 1;
        _standees = cp.reqStandees == 1;
        _smsBlast = cp.reqSmsBlast == 1;
        _whatsappBlast = cp.reqWhatsappBlast == 1;
        
        if (cp.fullAddress != null) {
          _addressController.text = cp.fullAddress!;
        }
      }
    });
  }

  void _onTeamMemberSelected(ContactPerson? member) {
    setState(() {
      _selectedTeamMember = member;
      if (member != null) {
        _contactPersonController.text = member.fullName ?? 'No Name';
        _mobileController.text = member.mobile ?? '';
      }
    });
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
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Select Channel Partner', 
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
                      controller: _cpSearchController,
                      autofocus: true,
                      decoration: kInputDecoration.copyWith(
                        hintText: 'Search by firm name, mobile or email...',
                        prefixIcon: const Icon(Icons.search, color: goldAccent),
                        suffixIcon: _cpSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _cpSearchController.clear();
                                  setModalState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) => setModalState(() {}),
                    ),
                  ),
                  Expanded(
                    child: filteredList.isEmpty
                        ? const Center(child: Text('No Channel Partners found'))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredList.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final cp = filteredList[index];
                              final isSelected = _selectedCP?.name == cp.name;
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                title: Text(cp.firmName ?? 'No Name', 
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? goldAccent : matteBlack,
                                  )),
                                subtitle: Text(cp.mobileNumber ?? cp.email ?? 'No Contact'),
                                trailing: isSelected ? const Icon(Icons.check_circle, color: goldAccent) : null,
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
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: goldAccent,
              onPrimary: Colors.white,
              onSurface: matteBlack,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _visitDate = picked;
      });
    }
  }

  String _getCoordinatesDisplay() {
    if (_locationController.text.isEmpty) return 'Not captured';
    try {
      final data = jsonDecode(_locationController.text);
      final coords = data['features'][0]['geometry']['coordinates'];
      return '${coords[1].toStringAsFixed(6)}, ${coords[0].toStringAsFixed(6)}';
    } catch (e) {
      return 'Invalid Format';
    }
  }

  Future<Map<String, dynamic>?> _showOtpDialog(Map<String, dynamic>? triggerResponse) async {
    String otp = '';
    bool isVerifying = false;
    
    // Extract OTP for debug if possible from Frappe's _server_messages
    String? debugOtp;
    try {
      if (triggerResponse != null && triggerResponse.containsKey('_server_messages')) {
        final List<dynamic> serverMessages = jsonDecode(triggerResponse['_server_messages']);
        if (serverMessages.isNotEmpty) {
          final Map<String, dynamic> firstMsg = jsonDecode(serverMessages[0]);
          final String msgText = firstMsg['message'] ?? '';
          final otpMatch = RegExp(r'OTP: <b>(\d+)</b>').firstMatch(msgText);
          if (otpMatch != null) {
            debugOtp = otpMatch.group(1);
          }
        }
      }
    } catch (e) {
      debugPrint('Error extracting debug OTP: $e');
    }

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: goldAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shield_outlined, color: goldAccent, size: 32),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Security Verification',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: matteBlack),
                ),
                const SizedBox(height: 8),
                Text(
                  'We\'ve sent a verification code to',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                Text(
                  _mobileController.text,
                  style: const TextStyle(color: matteBlack, fontSize: 15, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  decoration: kInputDecoration.copyWith(
                    counterText: '',
                    hintText: '• • • • • •',
                    hintStyle: TextStyle(color: Colors.grey[300], fontSize: 24, letterSpacing: 8),
                    prefixIcon: null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  onChanged: (value) => otp = value,
                  style: const TextStyle(fontSize: 24, letterSpacing: 12, fontWeight: FontWeight.w900, color: goldAccent),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Debug Information Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: offWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.terminal_rounded, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 6),
                              Text('DEVELOPER DEBUG', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey[600], letterSpacing: 0.5)),
                            ],
                          ),
                          if (debugOtp != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: matteBlack,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(debugOtp, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Text(
                        jsonEncode(triggerResponse),
                        style: TextStyle(fontSize: 9, color: Colors.grey[600], fontFamily: 'monospace', height: 1.4),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Action Buttons
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: matteBlack,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: isVerifying
                        ? null
                        : () async {
                            if (otp.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter the verification code')),
                              );
                              return;
                            }
                            
                            setDialogState(() => isVerifying = true);
                            final success = await SourcingService.verifyOtp(_mobileController.text, otp);
                            setDialogState(() => isVerifying = false);
                            
                            if (success) {
                              Navigator.pop(context, {'verified': true, 'otp': otp});
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Verification failed. Please check the code.'),
                                  backgroundColor: Colors.redAccent,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                    child: isVerifying
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : const Text('Verify OTP', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.pop(context, null),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: Text('Cancel', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    String? enteredOtp;
    int isVerified = 0;

    // Trigger OTP if creating new sourcing
    if (widget.existingSourcing == null) {
      final triggerResponse = await SourcingService.triggerOtp(_mobileController.text);
      if (triggerResponse == null) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send OTP. Please try again.')),
          );
        }
        return;
      }

      final otpResult = await _showOtpDialog(triggerResponse);
      if (otpResult == null || otpResult['verified'] != true) {
        setState(() => _isLoading = false);
        return;
      }
      
      enteredOtp = otpResult['otp'];
      isVerified = 1;
    }

    final user = await AuthService.getUserData();
    final email = user?['email'] ?? user?['name'] ?? '';

    final sourcing = Sourcing(
      name: widget.existingSourcing?.name,
      salesPartner: _selectedCP?.name,
      customChannelPartner: _selectedCP?.name,
      channelPartner: _selectedCP?.name,
      contactPersonMet: _contactPersonController.text,
      mobileNumber: _mobileController.text,
      whatsappNumber: _whatsappController.text,
      visitStatus: _visitStatus,
      visitDate: DateFormat('yyyy-MM-dd HH:mm:ss').format(_visitDate),
      nextFollowUp: DateFormat('yyyy-MM-dd HH:mm:ss').format(_nextFollowUpDate),
      interestedProject: _interestedProject,
      remark: _remarkController.text,
      address: _addressController.text,
      location: _locationController.text,
      digital: _digital ? 1 : 0,
      reference: _reference ? 1 : 0,
      dataCalling: _dataCalling ? 1 : 0,
      retail: _retail ? 1 : 0,
      underConstruction: _underConstruction ? 1 : 0,
      rental: _rental ? 1 : 0,
      readyToMove: _readyToMove ? 1 : 0,
      callingSupport: _callingSupport ? 1 : 0,
      digitalKit: _digitalKit ? 1 : 0,
      standees: _standees ? 1 : 0,
      smsBlast: _smsBlast ? 1 : 0,
      whatsappBlast: _whatsappBlast ? 1 : 0,
      visitType: _visitType,
      cpInterest: _cpInterest,
      enterOtp: enteredOtp,
      isVerified: isVerified,
    );

    bool success;
    if (widget.existingSourcing == null) {
      final result = await SourcingService.createSourcing(sourcing);
      success = result != null;
    } else {
      final result = await SourcingService.updateSourcing(sourcing);
      success = result != null;
    }

    setState(() => _isLoading = false);

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Sourcing saved successfully'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save sourcing'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.existingSourcing == null ? 'Create Sourcing' : 'Edit Sourcing',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: matteBlack,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading && _channelPartners.isEmpty
          ? const Center(child: CircularProgressIndicator(color: goldAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Channel Partner Details'),
                    _buildFormCard([
                      TextFormField(
                        controller: _cpDisplayController,
                        readOnly: true,
                        decoration: kInputDecoration.copyWith(
                          labelText: 'Select Channel Partner',
                          prefixIcon: const Icon(Icons.business_rounded, color: goldAccent),
                          suffixIcon: const Icon(Icons.arrow_drop_down, color: goldAccent),
                        ),
                        onTap: _showCPPicker,
                        validator: (v) => _selectedCP == null ? 'Required' : null,
                      ),
                    ]),

                    const SizedBox(height: 24),
                    _buildSectionHeader('Contact Information'),
                    _buildFormCard([
                      if (_cpTeamMembers.isNotEmpty) ...[
                        DropdownButtonFormField<ContactPerson>(
                          value: _selectedTeamMember,
                          dropdownColor: Colors.white,
                          decoration: kInputDecoration.copyWith(
                            labelText: 'Contact Person Met *',
                            prefixIcon: const Icon(Icons.person_outline, color: goldAccent),
                          ),
                          items: _cpTeamMembers
                              .map((m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(m.fullName ?? 'No Name', 
                                      style: const TextStyle(fontSize: 14)),
                                  ))
                              .toList(),
                          onChanged: _onTeamMemberSelected,
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                      ] else ...[
                        TextFormField(
                          controller: _contactPersonController,
                          decoration: kInputDecoration.copyWith(
                            labelText: 'Contact Person Met *',
                            prefixIcon: const Icon(Icons.person_outline, color: goldAccent),
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _mobileController,
                        decoration: kInputDecoration.copyWith(
                          labelText: 'Mobile Number *',
                          prefixIcon: const Icon(Icons.phone_android_rounded, color: goldAccent),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _whatsappController,
                        decoration: kInputDecoration.copyWith(
                          labelText: 'WhatsApp Number',
                          prefixIcon: const Icon(Icons.chat_bubble_outline_rounded, color: goldAccent),
                        ),
                        keyboardType: TextInputType.phone,
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
                          prefixIcon: const Icon(Icons.info_outline_rounded, color: goldAccent),
                        ),
                        items: ['Visit Done', 'Revisit Done', 'Revisit Scheduled']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setState(() => _visitStatus = v!),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _visitType,
                        dropdownColor: Colors.white,
                        decoration: kInputDecoration.copyWith(
                          labelText: 'Visit Type',
                          prefixIcon: const Icon(Icons.category_outlined, color: goldAccent),
                        ),
                        items: ['Open', 'Close']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setState(() => _visitType = v!),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _cpInterest,
                        dropdownColor: Colors.white,
                        decoration: kInputDecoration.copyWith(
                          labelText: 'CP Interest',
                          prefixIcon: const Icon(Icons.favorite_outline, color: goldAccent),
                        ),
                        items: ['Interested', 'Not Interested']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setState(() => _cpInterest = v!),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _interestedProject,
                        dropdownColor: Colors.white,
                        decoration: kInputDecoration.copyWith(
                          labelText: 'Interested Project',
                          prefixIcon: const Icon(Icons.apartment_rounded, color: goldAccent),
                        ),
                        items: _projects
                            .map((p) => DropdownMenuItem(
                                  value: p['id'],
                                  child: Text(p['name'] ?? 'Unknown Project', 
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _interestedProject = v),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _selectNextFollowUpDateTime,
                        child: InputDecorator(
                          decoration: kInputDecoration.copyWith(
                            labelText: 'Next Follow-up Date & Time',
                            prefixIcon: const Icon(Icons.notification_important_outlined, color: goldAccent),
                          ),
                          child: Text(
                            DateFormat('dd MMM yyyy, hh:mm a').format(_nextFollowUpDate),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _selectDate,
                        child: InputDecorator(
                          decoration: kInputDecoration.copyWith(
                            labelText: 'Visit Date',
                            prefixIcon: const Icon(Icons.calendar_today_rounded, color: goldAccent),
                          ),
                          child: Text(
                            DateFormat('dd MMM yyyy').format(_visitDate),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _remarkController,
                        decoration: kInputDecoration.copyWith(
                          labelText: 'Remark',
                          prefixIcon: const Icon(Icons.notes_rounded, color: goldAccent),
                        ),
                        maxLines: 3,
                      ),
                    ]),

                    const SizedBox(height: 24),
                    _buildSectionHeader('Location Info'),
                    _buildFormCard([
                      TextFormField(
                        controller: _addressController,
                        decoration: kInputDecoration.copyWith(
                          labelText: 'Address',
                          prefixIcon: const Icon(Icons.location_on_outlined, color: goldAccent),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.map_outlined, color: goldAccent, size: 20),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Location', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                              Text(
                                _getCoordinatesDisplay(),
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (_locationController.text.isNotEmpty)
                            IconButton(
                              onPressed: _openInMaps,
                              icon: const Icon(Icons.map_rounded, size: 20, color: goldAccent),
                              tooltip: 'Show on Maps',
                            ),
                          IconButton(
                            onPressed: _fetchCurrentLocation,
                            icon: const Icon(Icons.my_location_rounded, size: 20, color: goldAccent),
                            tooltip: 'Update Location',
                          ),
                        ],
                      ),
                    ]),

                    const SizedBox(height: 24),
                    _buildSectionHeader('Services & Support'),
                    _buildFormCard([
                      _buildSwitch('Digital Marketing', _digital, (v) => setState(() => _digital = v)),
                      _buildSwitch('Reference', _reference, (v) => setState(() => _reference = v)),
                      _buildSwitch('Data Calling', _dataCalling, (v) => setState(() => _dataCalling = v)),
                      _buildSwitch('Retail Presence', _retail, (v) => setState(() => _retail = v)),
                      _buildSwitch('Under Construction', _underConstruction, (v) => setState(() => _underConstruction = v)),
                      _buildSwitch('Rental Service', _rental, (v) => setState(() => _rental = v)),
                      _buildSwitch('Ready to Move', _readyToMove, (v) => setState(() => _readyToMove = v)),
                      _buildSwitch('Calling Support', _callingSupport, (v) => setState(() => _callingSupport = v)),
                      _buildSwitch('Digital Kit', _digitalKit, (v) => setState(() => _digitalKit = v)),
                      _buildSwitch('Standees', _standees, (v) => setState(() => _standees = v)),
                      _buildSwitch('SMS Blast', _smsBlast, (v) => setState(() => _smsBlast = v)),
                      _buildSwitch('WhatsApp Blast', _whatsappBlast, (v) => setState(() => _whatsappBlast = v)),
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
                        child: const Text(
                          'SAVE SOURCING',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildFormCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: goldAccent,
            activeTrackColor: goldAccent.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}
