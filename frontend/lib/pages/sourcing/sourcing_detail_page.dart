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
import 'package:url_launcher/url_launcher.dart';

const Color goldAccent = Color(0xFF675D40);
const Color matteBlack = Color(0xFF1A1A1A);
const Color offWhite = Color(0xFFF9F9F9);
const Color kBackgroundColor = Color(0xFFF2F2F7);

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
  String? _projectName;

  @override
  void initState() {
    super.initState();
    ScreenProtector.preventScreenshotOn();
    _sourcing = widget.sourcing;
    _refreshData();
  }

  @override
  void dispose() {
    ScreenProtector.preventScreenshotOff();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch full details as the list view might have partial data
      final updated = await SourcingService.getSourcingDetail(_sourcing.name!);
      if (updated != null) {
        _sourcing = updated;
      }
      
      // Load CP and Project names in parallel
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
    if (_sourcing.interestedProject == null) return;
    
    try {
      final projects = await ProjectService.fetchApiProjects();
      final matched = projects.where((p) => p['id'] == _sourcing.interestedProject).toList();
      if (matched.isNotEmpty) {
        _projectName = matched.first['name'];
      }
    } catch (e) {
      debugPrint('Error loading project data: $e');
    }
  }

  Future<void> _updateStatus(int status) async {
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
        title: const Text('Confirm Delete', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to permanently delete this sourcing entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),    );

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
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text('Sourcing Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: matteBlack,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context, true),
        ),
        actions: [
          if (_sourcing.docstatus == 0)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
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
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: goldAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 16),
                  _buildSectionCard('Channel Partner Details', [
                    _infoRow(Icons.business_rounded, "Channel Partner", _cpFirmName ?? _sourcing.channelPartnerId ?? 'N/A'),
                  ]),
                  const SizedBox(height: 16),
                  _buildSectionCard('Contact Information', [
                    _infoRow(Icons.person_outline, "Contact Person", _sourcing.contactPersonMet),
                    _infoRow(Icons.phone_android_rounded, "Mobile", _sourcing.mobileNumber),
                    _infoRow(Icons.chat_bubble_outline_rounded, "WhatsApp", _sourcing.whatsappNumber),
                  ]),
                  const SizedBox(height: 16),
                  _buildSectionCard('Visit Details', [
                    _infoRow(Icons.info_outline_rounded, "Visit Status", _sourcing.visitStatus, isStatus: true),
                    _infoRow(Icons.category_outlined, "Visit Type", _sourcing.visitType),
                    _infoRow(Icons.favorite_outline, "CP Interest", _sourcing.cpInterest),
                    _infoRow(Icons.apartment_rounded, "Interested Project", _projectName ?? _sourcing.interestedProject),
                    _infoRow(Icons.notification_important_outlined, "Next Follow-up", _sourcing.nextFollowUp != null ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(_sourcing.nextFollowUp!)) : 'N/A'),
                    _infoRow(Icons.calendar_today_rounded, "Visit Date", _sourcing.visitDate != null ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(_sourcing.visitDate!)) : 'N/A'),
                    _infoRow(Icons.notes_rounded, "Remark", _sourcing.remark),
                    const Divider(height: 24),
                    _infoRow(Icons.timer_outlined, "Visit Duration", "${_sourcing.visitDuration ?? 'N/A'} "),
                    _infoRow(Icons.coffee_outlined, "Did he offer coffee?", _sourcing.offeredCoffee == 1 ? "Yes" : "No"),
                    _infoRow(Icons.person_pin_outlined, "Did you meet the owner?", _sourcing.metTheOwner == 1 ? "Yes" : "No"),
                    _infoRow(Icons.trending_up_rounded, "Did the client ask about recent price trends in the area?", _sourcing.askedAboutPriceTrends == 1 ? "Yes" : "No"),
                    _infoRow(Icons.build_outlined, "Is the client considering redevelopment properties?", _sourcing.consideringRedevelopment == 1 ? "Yes" : "No"),
                    _infoRow(Icons.percent_rounded, "Are they concerned about current home loan interest rates?", _sourcing.concernedAboutInterestRates == 1 ? "Yes" : "No"),
                    _infoRow(Icons.compare_arrows_rounded, "Did they compare this locality to a neighboring micro-market?", _sourcing.comparedMicroMarkets == 1 ? "Yes" : "No"),
                    _infoRow(Icons.verified_user_outlined, "Is the client strictly looking for RERA-registered projects?", _sourcing.strictlyReraRegistered == 1 ? "Yes" : "No"),
                  ]),
                  const SizedBox(height: 16),
                  _buildLocationCard(),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: matteBlack,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: goldAccent.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.source_rounded, color: goldAccent, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _sourcing.name ?? 'N/A',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _cpFirmName ?? _sourcing.contactPersonMet ?? 'Unknown Contact',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                    ),
                  ],
                ),
              ),
              _buildDocStatusBadge(_sourcing.docstatus ?? 0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocStatusBadge(int status) {
    String text = 'Draft';
    Color color = Colors.orange;
    if (status == 1) {
      text = 'Submitted';
      color = Colors.green;
    } else if (status == 2) {
      text = 'Cancelled';
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: matteBlack)),
          const SizedBox(height: 16),
          _infoRow(Icons.location_on_outlined, "Address", _sourcing.address),
          const SizedBox(height: 8),
          if (_sourcing.location != null && _sourcing.location!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Map Preview", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
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
                        image: NetworkImage('https://static-maps.yandex.ru/1.x/?lang=en_US&ll=72.8529,19.2098&z=12&l=map&size=450,150'), // Dynamic placeholder or grid
                        fit: BoxFit.cover,
                        opacity: 0.3,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Grid pattern overlay for "map" look if image fails
                        Positioned.fill(
                          child: CustomPaint(
                            painter: GridPainter(),
                          ),
                        ),
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
                              child: const Text(
                                'Tap to View on Google Maps',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
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
              ],
            )
          else
            _infoRow(Icons.map_outlined, "Coordinates", "Not captured"),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: matteBlack)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String? value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: goldAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const SizedBox(height: 2),
                isStatus 
                  ? _buildStatusBadge(value ?? 'N/A')
                  : Text(
                      value == null || value.isEmpty ? 'Not Provided' : value,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: matteBlack),
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
      default: color = Colors.blue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }



  Widget _buildActionButtons() {
    return Column(
      children: [
        if (_sourcing.docstatus == 0) ...[
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () => _updateStatus(1),
              style: ElevatedButton.styleFrom(
                backgroundColor: goldAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('SUBMIT SOURCING', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              onPressed: _delete,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('DELETE SOURCING', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_sourcing.docstatus == 1) ...[
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              onPressed: () => _updateStatus(2),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('CANCEL SOURCING', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_sourcing.docstatus == 2) ...[
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _delete,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('DELETE SOURCING', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ],
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
