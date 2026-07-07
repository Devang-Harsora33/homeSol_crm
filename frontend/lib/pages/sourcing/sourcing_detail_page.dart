import 'package:flutter/material.dart';
import 'package:Homesol/utils/custom_snackbar.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:Homesol/models/sourcing.dart';
import 'package:Homesol/services/apis/sourcing/sourcing_service.dart';
import 'package:Homesol/services/apis/channel_partners/channel_partner.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'sourcing_create_page.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:Homesol/components/sourcing_questionnaire_popup.dart';

const Color goldAccent = Color(0xFF675D40);
const Color kBackgroundColor = Color(0xFFF5F7FA);
const Color matteBlack = Color(0xFF1A1A1A);
const Color offWhite = Color(0xFFF9F9F9);

class SourcingDetailPage extends StatefulWidget {
  final Sourcing sourcing;

  const SourcingDetailPage({super.key, required this.sourcing});

  @override
  State<SourcingDetailPage> createState() => _SourcingDetailPageState();
}

class _SourcingDetailPageState extends State<SourcingDetailPage> {
  late Sourcing _sourcing;
  bool _isLoading = false;
  String? _cpFirmName;
  List<String> _projectNames = [];

  @override
  void initState() {
    super.initState();
    // ScreenProtector.preventScreenshotOn();
    _sourcing = widget.sourcing;
    _refreshData();
  }

  @override
  void dispose() {
    // ScreenProtector.preventScreenshotOff();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      final updated = await SourcingService.getSourcingDetail(_sourcing.name!);
      if (updated != null) {
        _sourcing = updated;
      }
      
      await Future.wait([
        _loadCPData(),
        _loadProjectData(),
      ]);
    } catch (e) {
      debugPrint('Error refreshing sourcing detail: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadCPData() async {
    final cpId = _sourcing.channelPartnerId;
    if (cpId == null) return;
    
    try {
      final partners = await ChannelPartnerService.fetchAllChannelPartners();
      final matched = partners.where((p) => p.name == cpId).toList();
      if (matched.isNotEmpty) {
        setState(() {
          _cpFirmName = matched.first.firmName;
        });
      }
    } catch (e) {
      debugPrint('Error loading CP data: $e');
    }
  }

  Future<void> _loadProjectData() async {
    if (_sourcing.interestedProject == null || _sourcing.interestedProject!.isEmpty) {
      setState(() => _projectNames = []);
      return;
    }
    
    try {
      final projects = await ProjectService.fetchApiProjects();
      final List<String> names = [];
      for (var ip in _sourcing.interestedProject!) {
        final matched = projects.where((p) => p['id'] == ip.project).toList();
        if (matched.isNotEmpty && matched.first['name'] != null) {
          names.add(matched.first['name']!);
        } else if (ip.project != null) {
          names.add(ip.project!);
        }
      }
      setState(() {
        _projectNames = names;
      });
    } catch (e) {
      debugPrint('Error loading project data: $e');
    }
  }

  Future<void> _updateStatus(int status) async {
    if (status == 1 && _sourcing.visitStatus == 'Visit Scheduled') {
      await _askForDurationAndSubmit();
      return;
    }

    setState(() => _isLoading = true);
    final errorMsg = await SourcingService.updateDocStatus(_sourcing.name!, status);
    
    if (errorMsg == null) {
      await _refreshData();
      if (mounted) {
        CustomSnackBar.show(context, message: status == 1 ? 'Sourcing Submitted' : 'Sourcing Cancelled', isError: false, title: 'Notice');
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackBar.show(context, message: 'Failed to update status: $errorMsg', isError: true, title: 'Error');
      }
    }
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

  void _showQuestionnairePopup(Sourcing source, [int? calculatedMinutes]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SourcingQuestionnairePopup(
        source: source,
        initialCalculatedMinutes: calculatedMinutes,
        durationStringGenerator: _calculateDurationString,
        onSaved: () => _refreshData(),
      ),
    );
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
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 24),
                      const Icon(Icons.timer_outlined, size: 48, color: goldAccent),
                      const SizedBox(height: 16),
                      const Text('Sourcing Submitted!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: matteBlack)),
                      const SizedBox(height: 8),
                      Text('Duration recorded as ${_calculateDurationString(minutes)}.', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                      const SizedBox(height: 24),
                      Text('Opening Questionnaire in ${value.ceil()}s...', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: goldAccent)),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
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

  Future<void> _askForDurationAndSubmit() async {
    double visitDuration = 15;
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('Visit Duration', style: TextStyle(fontWeight: FontWeight.bold, color: matteBlack)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Please select the duration of the visit:'),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Duration', style: TextStyle(fontWeight: FontWeight.bold, color: matteBlack)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: goldAccent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _calculateDurationString(visitDuration.toInt()),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                      value: visitDuration,
                      min: 0,
                      max: 60,
                      divisions: 60,
                      label: '${visitDuration.toInt()} mins',
                      onChanged: (v) => setDialogState(() => visitDuration = v),
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (visitDuration > 0) {
                      Navigator.pop(context, visitDuration.toInt());
                    } else {
                      CustomSnackBar.show(context, message: 'Please select a valid duration', isError: true, title: 'Error');
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: goldAccent),
                  child: const Text('CONFIRM', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (minutes != null) {
      setState(() => _isLoading = true);
      try {
        await SourcingService.updateSourcingFields(_sourcing.name!, {
          'visit_duration': '$minutes mins',
          'visit_status': 'Visit Done',
        });
        setState(() {
          _sourcing.visitStatus = 'Visit Done';
          _sourcing.visitDuration = '$minutes mins';
        });
        final errorMsg = await SourcingService.updateDocStatus(_sourcing.name!, 1);
        
        if (errorMsg == null) {
          await _refreshData();
          if (mounted) {
            _showAutoOpenBottomSheet(_sourcing, minutes);
          }
        } else {
          if (mounted) {
            setState(() => _isLoading = false);
            CustomSnackBar.show(context, message: 'Failed to update status: $errorMsg', isError: true, title: 'Error');
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          CustomSnackBar.show(context, message: 'An error occurred: $e', isError: true, title: 'Error');
        }
      }
    }
  }

  Future<void> _openInMaps() async {
    if (_sourcing.location == null || _sourcing.location!.isEmpty) return;
    try {
      final data = jsonDecode(_sourcing.location!);
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

  String _getCoordinatesDisplay() {
    if (_sourcing.location == null || _sourcing.location!.isEmpty) return 'N/A';
    try {
      final data = jsonDecode(_sourcing.location!);
      final coords = data['features'][0]['geometry']['coordinates'];
      return '${coords[1].toStringAsFixed(6)}, ${coords[0].toStringAsFixed(6)}';
    } catch (e) {
      return 'Invalid Format';
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white, 
        surfaceTintColor: Colors.transparent, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Delete', style: TextStyle(fontWeight: FontWeight.w900, color: matteBlack)),
        content: const Text('Are you sure you want to permanently delete this sourcing entry?', style: TextStyle(color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final success = await SourcingService.deleteSourcing(_sourcing.name!);
      setState(() => _isLoading = false);

      if (success) {
        if (mounted) {
          CustomSnackBar.show(context, message: 'Sourcing deleted successfully');
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          CustomSnackBar.show(context, message: 'Failed to delete sourcing', isError: true, title: 'Error');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: kBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: goldAccent)),
      );
    }

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMetricsGrid(),
                      const SizedBox(height: 24),
                      _buildSectionCard('Contact Information', [
                        _infoRow(Icons.business_rounded, "Channel Partner", _cpFirmName ?? _sourcing.channelPartnerId ?? 'N/A'),
                        _infoRow(Icons.person_outline, "Contact Person", _sourcing.contactPersonMet),
                        _infoRow(Icons.phone_android_rounded, "Mobile", _sourcing.mobileNumber),
                        _infoRow(Icons.chat_bubble_outline_rounded, "WhatsApp", _sourcing.whatsappNumber),
                      ]),
                      const SizedBox(height: 24),
                      _buildSectionCard('Meeting Details', [
                        _infoRow(Icons.info_outline_rounded, "Visit Status", _sourcing.visitStatus, isStatus: true),
                        _infoRow(Icons.calendar_today_rounded, "Visit Date", _sourcing.visitDate != null ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(_sourcing.visitDate!)) : 'N/A'),
                        _infoRow(Icons.notification_important_outlined, "Next Follow-up", _sourcing.nextFollowUp != null ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(_sourcing.nextFollowUp!)) : 'N/A'),
                        _infoRow(Icons.coffee_outlined, "Offered Coffee?", _sourcing.offeredCoffee == 1 ? "Yes" : "No"),
                        _infoRow(Icons.person_pin_outlined, "Met the owner?", _sourcing.metTheOwner == 1 ? "Yes" : "No"),
                        _infoRow(Icons.home_work_outlined, "Current Demand", _sourcing.currentDemand == null || _sourcing.currentDemand!.isEmpty ? 'N/A' : _sourcing.currentDemand),
                        _infoRow(Icons.notes_rounded, "Remark", _sourcing.remark),
                      ]),
                      const SizedBox(height: 24),
                      _buildSectionCard('Projects & Location', [
                        _buildProjectsWrap(),
                        const SizedBox(height: 16),
                        _buildLocationCardInner(),
                      ]),
                      const SizedBox(height: 100), // padding for floating bar
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildFloatingBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 300.0,
      floating: false,
      pinned: true,
      backgroundColor: matteBlack,
      elevation: 0,
      stretch: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (_sourcing.docstatus == 0)
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SourcingCreatePage(existingSourcing: _sourcing),
                ),
              );
              if (result == true) {
                final sources = await SourcingService.getMySources();
                if (mounted) {
                  setState(() {
                    _sourcing = sources.firstWhere((s) => s.name == _sourcing.name);
                  });
                  _loadCPData();
                }
              } else if (result is Map && result['refresh'] == true) {
                 if (mounted) Navigator.pop(context, result);
              }
            },
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0xFF3A3A3A), matteBlack],
                  center: Alignment.topCenter,
                  radius: 1.2,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 30),
                  Hero(
                    tag: 'sourcing_avatar_${_sourcing.name}',
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: goldAccent.withOpacity(0.5), width: 2),
                        boxShadow: [
                          BoxShadow(color: goldAccent.withOpacity(0.2), blurRadius: 20, spreadRadius: 5),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.white,
                        child: Text(
                          (_cpFirmName?.isNotEmpty ?? false) ? _cpFirmName![0].toUpperCase() : 'S',
                          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: goldAccent),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _sourcing.name ?? 'N/A',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _cpFirmName ?? _sourcing.contactPersonMet ?? 'Unknown Contact',
                          style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildDocStatusBadge(_sourcing.docstatus ?? 0),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocStatusBadge(int status) {
    String text = 'DRAFT';
    Color color = Colors.orange;
    if (status == 1) {
      text = 'SUBMITTED';
      color = Colors.green;
    } else if (status == 2) {
      text = 'CANCELLED';
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildVisitTypeCard() {
    bool isOpen = (_sourcing.visitType ?? 'Open') != 'Close';
    return GestureDetector(
      onTap: () async {
        final newType = isOpen ? 'Close' : 'Open';
        setState(() {
          _sourcing.visitType = newType;
        });
        try {
          await SourcingService.updateSourcingFields(_sourcing.name!, {
            'visit_type': newType,
          });
        } catch (e) {
          debugPrint('Failed to save visit_type: $e');
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isOpen ? Colors.green.withOpacity(0.05) : Colors.redAccent.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isOpen ? Colors.green.withOpacity(0.3) : Colors.redAccent.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isOpen ? Icons.lock_open_rounded : Icons.lock_outline_rounded, size: 18, color: isOpen ? Colors.green : Colors.redAccent),
                const SizedBox(width: 8),
                Text('Visit Type', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isOpen ? 'Open' : 'Close',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isOpen ? Colors.green : Colors.redAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildVisitTypeCard()),
            const SizedBox(width: 16),
            Expanded(child: _buildMetricCard('Interest', _sourcing.cpInterest ?? 'N/A', Icons.favorite_outline, const Color(0xFFF39C12))),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildMetricCard('Duration', '${_sourcing.visitDuration ?? 'N/A'}', Icons.timer_outlined, const Color(0xFF9B59B6))),
            const SizedBox(width: 16),
            Expanded(child: _buildMetricCard('Outlook', _sourcing.marketOutlook?.toString() ?? '0', Icons.trending_up_rounded, _getOutlookColor((_sourcing.marketOutlook ?? 0).toDouble()))),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: color),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: matteBlack, letterSpacing: -0.5),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsWrap() {
    if (_projectNames.isEmpty) {
      return _infoRow(Icons.apartment_rounded, "Interested Project", 'N/A');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: kBackgroundColor, shape: BoxShape.circle),
              child: const Icon(Icons.apartment_rounded, size: 18, color: goldAccent),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Interested Projects", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 54.0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _projectNames.map((name) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Text(
                name,
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCardInner() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoRow(Icons.location_on_outlined, "Address", _sourcing.address),
        if (_sourcing.location != null && _sourcing.location!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text("Map Preview", style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _openInMaps,
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: offWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                image: const DecorationImage(
                  image: NetworkImage('https://static-maps.yandex.ru/1.x/?lang=en_US&ll=72.8529,19.2098&z=12&l=map&size=450,150'),
                  fit: BoxFit.cover,
                  opacity: 0.3,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(child: CustomPaint(painter: GridPainter())),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 40),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: matteBlack.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Tap to View on Maps', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: 8,
                    right: 12,
                    child: Text(
                      _getCoordinatesDisplay(),
                      style: TextStyle(fontSize: 10, color: matteBlack.withOpacity(0.5), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          _infoRow(Icons.map_outlined, "Coordinates", "Not captured"),
        ],
      ],
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: matteBlack, letterSpacing: 0.5)),
          const SizedBox(height: 24),
          ...children,
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

  Widget _infoRow(IconData icon, String label, String? value, {bool isStatus = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: kBackgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: goldAccent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                isStatus 
                  ? _buildStatusBadge(value ?? 'N/A')
                  : Text(
                      value == null || value.isEmpty ? 'Not Provided' : value,
                      style: TextStyle(
                        fontSize: 14, 
                        fontWeight: FontWeight.w800, 
                        color: color ?? matteBlack,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'Visit Done': color = Colors.green; break;
      case 'Revisit Done': color = Colors.blue; break;
      case 'Revisit Scheduled': color = Colors.orange; break;
      case 'Interested': color = Colors.green; break;
      case 'Not Interested': color = Colors.red; break;
      case 'Follow-up': color = Colors.orange; break;
      default: color = Colors.blueGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildFloatingBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5)),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Row(
        children: [
          if (_sourcing.docstatus == 0) ...[
            Expanded(
              child: ElevatedButton(
                onPressed: () => _updateStatus(1),
                style: ElevatedButton.styleFrom(
                  backgroundColor: matteBlack,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('SUBMIT', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 12),
          ] else if (_sourcing.docstatus == 1) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () => _updateStatus(2),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.redAccent, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('CANCEL SOURCING', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 12),
          ],
          
          if (_sourcing.docstatus != 1)
            IconButton(
              onPressed: _delete,
              style: IconButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.1),
                foregroundColor: Colors.red,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..strokeWidth = 1.0;

    const double step = 20.0;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
