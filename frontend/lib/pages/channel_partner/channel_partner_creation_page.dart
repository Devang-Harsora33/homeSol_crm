import 'package:Homesol/services/apis/channel_partners/channel_partner.dart';
import 'package:Homesol/services/apis/leads/lead_service.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
// import 'dart:io';
// import 'dart:convert';
import '../../services/api_service.dart';

// Reusing styles from LeadCreationPage
const kAccent = Color(0xFF675D40);
const kInputDecoration = InputDecoration(
  isDense: true,
  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: Colors.black12),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: Colors.black12),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: kAccent, width: 2),
  ),
);

class ChannelPartnerCreationPage extends StatefulWidget {
  const ChannelPartnerCreationPage({super.key});

  @override
  State<ChannelPartnerCreationPage> createState() =>
      _ChannelPartnerCreationPageState();
}

class _ChannelPartnerCreationPageState extends State<ChannelPartnerCreationPage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};
  int _step = 0;
  bool _isLoading = false;
  bool _isGettingLocation = false;
  String? _locationError;
  List<Map<String, String>> _contactPersons = [];
  List<Map<String, dynamic>> _documents = [];
  List<String> _territories = [];
  bool _isFetchingTerritories = true;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchDropdownData() async {
    setState(() {
      _isFetchingTerritories = true;
    });
    try {
      final territories = await LeadService.fetchTerritories();
      setState(() {
        _territories = territories;
        _isFetchingTerritories = false;
      });
    } catch (e) {
      setState(() {
        _isFetchingTerritories = false;
      });
      // Optionally show an error message
    }
  }

    Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Initial Channel Partner Creation (without documents and contact persons yet)
      final initialPayload = Map<String, dynamic>.from(_formData);
      initialPayload['contact_persons'] = []; // Send empty for initial creation
      initialPayload['documents'] = []; // Send empty for initial creation

      final newChannelPartnerName = await ChannelPartnerService.createChannelPartner(initialPayload);

      if (newChannelPartnerName == null) {
        throw Exception('Failed to create Channel Partner initially.');
      }

      // 2. Upload Documents and prepare final document data
      List<Map<String, dynamic>> finalDocumentsData = [];
      for (var i = 0; i < _documents.length; i++) {
        final doc = _documents[i];
        String? uploadedFileUrl;
        if (doc['document_attachment'] != null &&
            doc['document_attachment'] is String &&
            !(doc['document_attachment'] as String).startsWith('/files/') && // Check if it's a local path
            !(doc['document_attachment'] as String).startsWith('http')) {
          
          final filePath = doc['document_attachment'] as String;
          // final file = File(filePath);
          // final fileBytes = await file.readAsBytes();
          final base64Data = 'data:;base64,';

          uploadedFileUrl = await ApiService.uploadFile(
            filename: doc['document_name'] ?? filePath.split('/').last,
            filedata: base64Data,
            doctype: "Channel Partner",
            docname: newChannelPartnerName,
            folder: "Home",
          );

          print("Uploaded file URL: ");
          if (uploadedFileUrl != null) {
            setState(() {
              _documents[i]['is_uploaded'] = true;
            });
          }

        } else {
          // If already a URL or null, keep it as is
          uploadedFileUrl = doc['document_attachment'] as String?;
        }
        
        finalDocumentsData.add({
          "document_name": doc['document_name'],
          "document_attachment": uploadedFileUrl,
        });
      }

      print("Final documents data: ");

      // 3. Prepare final contact persons data
      // Ensure contact persons have a parent and parenttype set for submission
      final finalContactPersonsData = _contactPersons.map((person) {
        return {
          ...person,
          "parent": newChannelPartnerName,
          "parenttype": "Channel Partner",
          "parentfield": "contact_persons", // Field name in the doctype
        };
      }).toList();

      // 4. Update Channel Partner with full data
      final finalPayload = Map<String, dynamic>.from(_formData);
      finalPayload['name'] = newChannelPartnerName; // Ensure name is in payload for update
      finalPayload['contact_persons'] = finalContactPersonsData;
      finalPayload['documents'] = finalDocumentsData;

      print("Final payload: ");

      final updateResponse = await ChannelPartnerService.updateChannelPartner(finalPayload);

      if (updateResponse) { // Assuming updateChannelPartner returns a boolean
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Channel Partner created and updated successfully!')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update Channel Partner after creation.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: ')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }void _scrollToTop() {
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Widget _stepHeader() {
    final steps = ['Basic Info', 'Address', 'Contacts', 'Documents & Flags'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: List.generate(steps.length, (i) {
          final active = i <= _step;
          final isCurrent = i == _step;
          return Expanded(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: active ? kAccent : Colors.grey.shade200,
                    shape: BoxShape.circle,
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: kAccent.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: i < _step
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: active ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  steps[i],
                  style: TextStyle(
                    fontSize: 11,
                    color: active ? Colors.black87 : Colors.grey,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return _buildBasicInfoStep();
      case 1:
        return _buildAddressStep();
      case 2:
        return _buildContactsStep();
      case 3:
        return _buildDocumentsAndFlagsStep();
      default:
        return Center(child: Text("Step ${_step + 1}"));
    }
  }

  Widget _buildBasicInfoStep() {
    return _card([
      Text("Basic Information", style: Theme.of(context).textTheme.titleMedium),
      const Divider(),
      _text('firm_name', 'Firm Name', (v) => _formData['firm_name'] = v,
          required: true),
      _text('email', 'Email', (v) => _formData['email'] = v,
          required: true, type: TextInputType.emailAddress),
      _text('mobile_number', 'Mobile Number', (v) => _formData['mobile_number'] = v,
          required: true, type: TextInputType.phone),
      _text('rera_number', 'RERA Number', (v) => _formData['rera_number'] = v),
      _dropdown('category', 'Category', ['Individual', 'Company'], (v) {
        setState(() {
          _formData['category'] = v;
        });
      }),
      _dropdown('territory', 'Territory', _territories, (v) {
        setState(() {
          _formData['territory'] = v;
        });
      }, isLoading: _isFetchingTerritories),
    ]);
  }

  Widget _buildContactsStep() {
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _contactPersons.length,
          itemBuilder: (context, index) {
            return _card([
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Contact Person ${index + 1}",
                      style: Theme.of(context).textTheme.titleMedium),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _contactPersons.removeAt(index);
                      });
                    },
                  ),
                ],
              ),
              const Divider(),
              _text('full_name_$index', 'Full Name', (v) {},
                  initialValue: _contactPersons[index]['full_name'],
                  onChanged: (v) => _contactPersons[index]['full_name'] = v,
                  required: true),
              _dynamicDropdown(
                'Roles',
                ['Manager', 'Owner', 'Sales'],
                _contactPersons[index]['roles'],
                (v) {
                  setState(() {
                    _contactPersons[index]['roles'] = v ?? 'Sales';
                  });
                },
              ),
              _text('mobile_$index', 'Mobile', (v) {},
                  initialValue: _contactPersons[index]['mobile'],
                  onChanged: (v) => _contactPersons[index]['mobile'] = v,
                  type: TextInputType.phone),
              _text('email_$index', 'Email', (v) {},
                  initialValue: _contactPersons[index]['email'],
                  onChanged: (v) => _contactPersons[index]['email'] = v,
                  type: TextInputType.emailAddress),
            ]);
          },
        ),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _contactPersons.add({
                'full_name': '',
                'roles': 'Sales',
                'mobile': '',
                'email': '',
              });
            });
          },
          icon: const Icon(Icons.add),
          label: const Text("Add Contact"),
        ),
      ],
    );
  }

  Widget _buildAddressStep() {
    return _card([
      Text("Address & Location",
          style: Theme.of(context).textTheme.titleMedium),
      const Divider(),
      _text('full_address', 'Full Address', (v) => _formData['full_address'] = v,
          required: true),
      _buildLocationWidget(),
    ]);
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
      _locationError = null;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = 'Location permissions are denied';
            _isGettingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError =
              'Location permissions are permanently denied, we cannot request permissions.';
          _isGettingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _formData['location'] =
            '{"type":"FeatureCollection","features":[{"type":"Feature","properties":{"point_type":"marker"},"geometry":{"type":"Point","coordinates":[${position.longitude},${position.latitude}]}}]}';
        _isGettingLocation = false;
      });
    } catch (e) {
      setState(() {
        _locationError = 'Failed to get location: $e';
        _isGettingLocation = false;
      });
    }
  }
  
  Widget _buildLocationWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _isGettingLocation ? null : _getCurrentLocation,
              icon: _isGettingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.location_on),
              label: const Text('Get Location'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: (_formData['location'] != null &&
                      _formData['location'].isNotEmpty)
                  ? const Icon(Icons.check_circle_outline, color: Colors.green)
                  : const Text(
                      'No location set',
                      style: TextStyle(fontSize: 12),
                    ),
            ),
          ],
        ),
        if (_locationError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              _locationError!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

    Widget _buildDocumentsAndFlagsStep() {
    return Column(
      children: [
        _card([
          Text("Documents (currently not working)", style: Theme.of(context).textTheme.titleMedium),
          const Divider(),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _documents.length,
            itemBuilder: (context, index) {
              final doc = _documents[index];
              final isUploaded = doc['is_uploaded'] == true;
              return Row(
                children: [
                  Expanded(
                    child: _text(
                      'document_name_',
                      'Document Name',
                      (v) {},
                      initialValue: doc['document_name'],
                      onChanged: (v) => doc['document_name'] = v,
                    ),
                  ),
                  if (isUploaded)
                    const Icon(Icons.check_circle, color: Colors.green)
                  else
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      onPressed: () => _pickFile(index),
                    ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _documents.removeAt(index);
                      });
                    },
                  ),
                ],
              );
            },
          ),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _documents.add({
                  'document_name': '',
                  'document_attachment': null,
                  'is_uploaded': false, // Initialize with not uploaded
                });
              });
            },
            icon: const Icon(Icons.add),
            label: const Text("Add Document"),
          ),
        ]),
        _card([
          Text("Flags", style: Theme.of(context).textTheme.titleMedium),
          const Divider(),
          _buildFlags(),
        ]),
      ],
    );
  }  Future<void> _pickFile(int index) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    print("Picked file: ${pickedFile?.path}");
    if (pickedFile != null) {
      setState(() {
        _documents[index]['document_attachment'] = pickedFile.path;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File picking cancelled.')),
      );
    }
  }Widget _buildFlags() {
  final flags = [
    'is_digital',
    'is_reference',
    'is_data_calling',
    'is_retail',
    'is_under_construction',
    'is_rental',
    'is_ready_to_move',
    'req_calling_support',
    'req_digital_kit',
    'req_standees',
    'req_sms_blast',
    'req_whatsapp_blast',
  ];

  return LayoutBuilder(
    builder: (context, constraints) {
      // Calculate width: (Total width - spacing) / 2 columns
      final double itemWidth = (constraints.maxWidth - 10) / 2;

      return Wrap(
        spacing: 10, // Horizontal space between columns
        runSpacing: 10, // Vertical space between rows
        children: flags.map((flag) {
          return SizedBox(
            width: itemWidth, // Forces exactly 2 columns
            child: CheckboxListTile(
              // Formatting the text
              title: Text(
                flag.replaceAll('_', ' ').split(' ').map((l) => l[0].toUpperCase() + l.substring(1)).join(' '),
                style: const TextStyle(fontSize: 13), // Slightly smaller text to fit
                maxLines: 2, // Allow 2 lines if needed
                overflow: TextOverflow.ellipsis,
              ),
              value: _formData[flag] == 1,
              onChanged: (bool? value) {
                setState(() {
                  _formData[flag] = value == true ? 1 : 0;
                });
              },
              // UI Compactness settings
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true, // Removes extra vertical padding
              visualDensity: VisualDensity.compact, // Removes extra horizontal padding
            ),
          );
        }).toList(),
      );
    },
  );
}
  Widget _dynamicDropdown(
    String label,
    List<String> items,
    String? currentValue,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: currentValue,
      decoration: kInputDecoration.copyWith(
        labelText: label,
      ),
      dropdownColor: Colors.white, // Added this line
      items: items.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children
            .map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: e,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _text(
    String keyName,
    String label,
    Function(String?) onSave, {
    bool required = false,
    TextInputType type = TextInputType.text,
    TextEditingController? controller,
    Function(String)? onChanged,
    String? initialValue,
  }) {
    return TextFormField(
      key: ValueKey(keyName),
      controller: controller,
      initialValue: initialValue ?? (controller == null ? _formData[keyName]?.toString() : null),
      keyboardType: type,
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: kInputDecoration.copyWith(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600),
      ),
      validator: required ? (v) => v!.isEmpty ? 'Required' : null : null,
      onSaved: onSave,
      onChanged: onChanged ?? (val) {
        if (controller == null) _formData[keyName] = val;
      },
    );
  }

  Widget _dropdown(
    String keyName,
    String label,
    List<String> items,
    Function(String?) onChange, {
    bool isLoading = false,
  }) {
    return DropdownButtonFormField<String>(
      key: ValueKey(keyName),
      value: _formData[keyName],
      decoration: kInputDecoration.copyWith(
        labelText: label,
        suffixIcon: isLoading
            ? Transform.scale(
                scale: 0.5,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
      ),
      dropdownColor: Colors.white,
      isExpanded: true,
      items: items.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        );
      }).toList(),
      onChanged: isLoading ? null : onChange,
      onSaved: onChange,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text(
          'Create Channel Partner',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            _stepHeader(),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: _stepBody(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: Row(
          children: [
            if (_step > 0)
              Expanded(
                child: TextButton(
                  onPressed: () {
                    setState(() => _step--);
                    _scrollToTop();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: Colors.grey.shade800,
                  ),
                  child: const Text('Back'),
                ),
              ),
            if (_step > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading ? null : () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    if (_step < 3) {
                      setState(() => _step++);
                      _scrollToTop();
                    } else {
                      _submitForm();
                    }
                  }
                },
                child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                  _step < 3 ? 'Next' : 'Submit',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
