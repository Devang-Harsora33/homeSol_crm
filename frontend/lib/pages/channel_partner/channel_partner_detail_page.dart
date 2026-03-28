import 'package:Homesol/services/apis/channel_partners/channel_partner.dart';
import 'package:Homesol/services/apis/leads/lead_service.dart';
import 'package:Homesol/services/apis/site_visits/sitevisit_service.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/channel_partner.dart';
import '../../models/lead.dart' as model_lead;
import '../../services/auth_service.dart';

const kAccent = Color(0xFF675D40);
const kBackgroundColor = Color(0xFFF2F2F7);
const kCardBorderRadius = 16.0;

class ChannelPartnerDetailPage extends StatefulWidget {
  final String partnerId;

  const ChannelPartnerDetailPage({super.key, required this.partnerId});

  @override
  State<ChannelPartnerDetailPage> createState() => _ChannelPartnerDetailPageState();
}

class _ChannelPartnerDetailPageState extends State<ChannelPartnerDetailPage> {
  ChannelPartner? _partner;
  List<model_lead.Lead> _connectedLeads = [];
  Map<String, String> _projectNames = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPartnerDetails();
  }

  Future<void> _fetchPartnerDetails() async {
    try {
      final partner = await ChannelPartnerService.fetchChannelPartner(widget.partnerId);
      final leads = await LeadService.getLeadsByChannelPartner(widget.partnerId);
      final projects = await ProjectService.fetchProjects();
      
      final projectMap = <String, String>{};
      for (var project in projects) {
        projectMap[project.id] = project.projectName;
      }

      setState(() {
        _partner = partner;
        _connectedLeads = leads;
        _projectNames = projectMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(_partner?.firmName ?? 'Channel Partner', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _buildBody(),
    );
  }

  Future<void> _refreshData() async {
    try {
      // Sync Leads and Site Visits as requested
      await LeadService.syncMyLeads();
      await SiteVisitService.fetchMySiteVisits(forceRefresh: true);
      await _fetchPartnerDetails();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error refreshing data: $e')),
      );
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_errorMessage'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchPartnerDetails,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_partner == null) {
      return const Center(child: Text('Partner not found.'));
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildSectionCard("Firm Details", [
              _infoRow(Icons.business, "Firm Name", _partner!.firmName),
              _infoRow(Icons.email_outlined, "Email", _partner!.email),
              _infoRow(Icons.phone_android, "Mobile Number", _partner!.mobileNumber),
              _infoRow(Icons.confirmation_number_outlined, "RERA Number", _partner!.reraNumber),
              _infoRow(Icons.category_outlined, "Category", _partner!.category),
              _infoRow(Icons.public_outlined, "Territory", _partner!.territory),
            ]),
            const SizedBox(height: 16),
            _buildSectionCard("Connected Leads", [
              if (_connectedLeads.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text("No leads connected with this partner", style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic)),
                )
              else
                ..._connectedLeads.map((lead) => _buildLeadCard(lead)).toList()
            ]),
            const SizedBox(height: 16),
            _buildSectionCard("Address", [
              _infoRow(Icons.location_on_outlined, "Full Address", _partner!.fullAddress),
            ]),
            const SizedBox(height: 16),
            _buildSectionCard("Contact Persons",
              _partner!.contactPersons?.map((p) => _buildContactPersonCard(p)).toList() ?? []
            ),
            const SizedBox(height: 16),
             _buildSectionCard("Documents",
              _partner!.documents?.map((d) => _buildDocumentCard(d)).toList() ?? []
            ),
            const SizedBox(height: 16),
            _buildSectionCard("Flags", [_buildFlags()]),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadCard(model_lead.Lead lead) {
    return Card(
      color: const Color(0xFFF9F9F9),
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    lead.customerName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildLeadStatusBadge(lead.customLeadStatus),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.business, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _projectNames[lead.customInterestedProject] ?? lead.customInterestedProject ?? 'No project specified',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadStatusBadge(String? status) {
    final statusText = status ?? 'Open';
    final normalizedStatus = statusText.toLowerCase();

    Color baseColor = Colors.grey.shade600;
    IconData iconData = Icons.help_outline_rounded;

    if (normalizedStatus == 'open') {
      baseColor = Colors.blue.shade700;
      iconData = Icons.radio_button_checked_rounded;
    } else if (normalizedStatus == 'prospect') {
      baseColor = Colors.orange.shade800;
      iconData = Icons.person_search_rounded;
    } else if (normalizedStatus == 'won') {
      baseColor = Colors.green.shade700;
      iconData = Icons.check_circle_rounded;
    } else if (normalizedStatus == 'lost') {
      baseColor = Colors.red.shade700;
      iconData = Icons.cancel_rounded;
    } else if (normalizedStatus.contains('interested')) {
      baseColor = Colors.blue.shade700;
      iconData = Icons.star_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: baseColor.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 14, color: baseColor),
          const SizedBox(width: 6),
          Text(
            statusText.toUpperCase(),
            style: TextStyle(
              color: baseColor,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kCardBorderRadius),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: kAccent.withOpacity(0.1),
            child: Text(
              (_partner!.firmName?.isNotEmpty ?? false) ? _partner!.firmName![0].toUpperCase() : 'C',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kAccent),
            ),
          ),
          const SizedBox(height: 12),
          Text(_partner!.firmName ?? 'N/A', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kCardBorderRadius),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade400),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildContactPersonCard(ContactPerson person) {
    return Card(
      color: const Color(0xFFF9F9F9),
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(person.fullName ?? 'N/A',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            if (person.roles != null && person.roles!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(person.roles!,
                    style: const TextStyle(
                        fontSize: 14, color: Colors.grey)),
              ),
            const Divider(height: 20),
            if (person.mobile != null && person.mobile!.isNotEmpty)
              _infoRow(Icons.phone, "Mobile", person.mobile),
            if (person.email != null && person.email!.isNotEmpty)
              _infoRow(Icons.email, "Email", person.email),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (person.mobile != null && person.mobile!.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.call, color: Colors.green),
                    onPressed: () async {
                      final url = 'tel:${person.mobile}';
                      if (await canLaunchUrl(Uri.parse(url))) {
                        await launchUrl(Uri.parse(url));
                      }
                    },
                  ),
                if (person.mobile != null && person.mobile!.isNotEmpty)
                  IconButton(
                    icon: const Icon(FontAwesomeIcons.whatsapp, color: Colors.green),
                    onPressed: () async {
                      final url = 'https://wa.me/${person.mobile}';
                       if (await canLaunchUrl(Uri.parse(url))) {
                        await launchUrl(Uri.parse(url));
                      }
                    },
                  ),
                if (person.email != null && person.email!.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.email, color: Colors.blue),
                    onPressed: () async {
                       final url = 'mailto:${person.email}';
                       if (await canLaunchUrl(Uri.parse(url))) {
                        await launchUrl(Uri.parse(url));
                      }
                    },
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(Document doc) {
    final isImage = ['.png', '.jpg', '.jpeg', '.gif', '.bmp']
        .any((ext) => doc.documentAttachment?.toLowerCase().endsWith(ext) ?? false);

    return InkWell(
      onTap: () async {
        if (doc.documentAttachment != null && doc.documentAttachment!.isNotEmpty) {
          final url = '${AuthService.baseUrl}${doc.documentAttachment}';
          if (isImage) {
            _openImageViewer(url);
          } else {
            if (await canLaunchUrl(Uri.parse(url))) {
              await launchUrl(Uri.parse(url));
            }
          }
        }
      },
      child: Card(
        color: const Color(0xFFF9F9F9),
      surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        child: ListTile(
          title: Text(doc.documentName ?? 'N/A'),
          subtitle: Text(doc.documentAttachment ?? 'No attachment'),
          leading: isImage ? const Icon(Icons.image) : const Icon(Icons.description),
          trailing: const Icon(Icons.open_in_new),
        ),
      ),
    );
  }

  Future<void> _openImageViewer(String imageUrl) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => Stack(
        children: [
          InteractiveViewer(
            child: Center(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) =>
                    const Center(child: Icon(Icons.error, color: Colors.red)),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlags() {
    final List<Map<String, dynamic>> flags = [
      {'label': 'Digital', 'icon': Icons.computer, 'value': _partner!.isDigital},
      {'label': 'Reference', 'icon': Icons.person_add_alt_1, 'value': _partner!.isReference},
      {'label': 'Data Calling', 'icon': Icons.phone_callback, 'value': _partner!.isDataCalling},
      {'label': 'Retail', 'icon': Icons.storefront, 'value': _partner!.isRetail},
      {'label': 'Under Construction', 'icon': Icons.construction, 'value': _partner!.isUnderConstruction},
      {'label': 'Rental', 'icon': Icons.vpn_key, 'value': _partner!.isRental},
      {'label': 'Ready To Move', 'icon': Icons.home_work, 'value': _partner!.isReadyToMove},
      {'label': 'Calling Support', 'icon': Icons.support_agent, 'value': _partner!.reqCallingSupport},
      {'label': 'Digital Kit', 'icon': Icons.auto_fix_high, 'value': _partner!.reqDigitalKit},
      {'label': 'Standees', 'icon': Icons.branding_watermark, 'value': _partner!.reqStandees},
      {'label': 'SMS Blast', 'icon': Icons.sms, 'value': _partner!.reqSmsBlast},
      {'label': 'WhatsApp Blast', 'icon': FontAwesomeIcons.whatsapp, 'value': _partner!.reqWhatsappBlast},
    ];

    final activeFlags = flags.where((f) => f['value'] == 1).toList();

    if (activeFlags.isEmpty) {
      return const Text('No flags active', style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic));
    }

    return Wrap(
      spacing: 10.0,
      runSpacing: 10.0,
      children: activeFlags.map((flag) => _buildFlagBadge(flag['label'], flag['icon'])).toList(),
    );
  }

  Widget _buildFlagBadge(String label, dynamic icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kAccent.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon is IconData)
            Icon(icon, size: 14, color: kAccent)
          else
            FaIcon(icon as IconData, size: 14, color: kAccent),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kAccent,
            ),
          ),
        ],
      ),
    );
  }
}
