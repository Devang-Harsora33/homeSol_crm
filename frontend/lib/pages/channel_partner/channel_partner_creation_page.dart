import 'package:Homesol/services/apis/channel_partners/channel_partner.dart';
import 'package:Homesol/utils/custom_snackbar.dart';
import 'package:Homesol/services/apis/leads/lead_service.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
// import 'dart:io';
// import 'dart:convert';
import '../../services/api_service.dart';

import 'package:flutter/services.dart';

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

class _ChannelPartnerCreationPageState
    extends State<ChannelPartnerCreationPage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};
  int _step = 0;
  bool _isLoading = false;
  List<Map<String, String>> _contactPersons = [
    {'full_name': '', 'roles': 'Sales', 'mobile': '', 'email': ''},
  ];
  List<Map<String, dynamic>> _stationPreferences = [
    {'railway_route': 'Western', 'from_station': null, 'to_station': null},
  ];
  List<Map<String, dynamic>> _documents = [];

  List<Map<String, String>> _railwayStations = [];
  bool _isFetchingStations = true;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchStations();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchStations() async {
    setState(() {
      _isFetchingStations = true;
    });
    try {
      final stations = await ApiService.fetchRailwayStations();
      setState(() {
        _railwayStations = stations;
        _isFetchingStations = false;
      });
    } catch (e) {
      setState(() {
        _isFetchingStations = false;
      });
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
      initialPayload['station_preferences'] =
          []; // Send empty for initial creation
      initialPayload['mobile'] = _formData['mobile_number'];

      final newChannelPartner =
          await ChannelPartnerService.createChannelPartner(initialPayload);

      if (newChannelPartner == null || newChannelPartner.name == null) {
        throw Exception('Failed to create Channel Partner initially.');
      }

      final newChannelPartnerName = newChannelPartner.name!;

      // 2. Upload Documents and prepare final document data
      List<Map<String, dynamic>> finalDocumentsData = [];
      for (var i = 0; i < _documents.length; i++) {
        final doc = _documents[i];
        String? uploadedFileUrl;
        if (doc['document_attachment'] != null &&
            doc['document_attachment'] is String &&
            !(doc['document_attachment'] as String).startsWith(
              '/files/',
            ) && // Check if it's a local path
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

      // 4. Prepare final station preferences data
      final finalStationPreferencesData = _stationPreferences.map((pref) {
        return {
          ...pref,
          "parent": newChannelPartnerName,
          "parenttype": "Channel Partner",
          "parentfield": "station_preferences",
        };
      }).toList();

      // 5. Update Channel Partner with full data
      final finalPayload = Map<String, dynamic>.from(_formData);
      finalPayload['name'] =
          newChannelPartnerName; // Ensure name is in payload for update
      finalPayload['contact_persons'] = finalContactPersonsData;
      finalPayload['documents'] = finalDocumentsData;
      finalPayload['station_preferences'] = finalStationPreferencesData;
      finalPayload['mobile'] = _formData['mobile_number'];

      print("Final payload: ");

      final updateResponse = await ChannelPartnerService.updateChannelPartner(
        finalPayload,
      );

      if (updateResponse != null) {
        // updateChannelPartner now returns ChannelPartner?
        CustomSnackBar.show(context, message: 'Channel Partner created and updated successfully!');
        Navigator.of(
          context,
        ).pop(true); // Return true to signal success to the caller
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update Channel Partner after creation.'),
          ),
        );
      }
    } catch (e) {
      print('Error in _submitForm: $e');
      CustomSnackBar.show(context, message: 'An error occurred: $e', isError: true, title: 'Error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Widget _stepHeader() {
    final steps = [
      'Basic Info',
      'Address',
      'Contacts',
      'Stations',
      'Docs & Flags',
    ];
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
                    fontSize: 10,
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
        return _buildStationPreferencesStep();
      case 4:
        return _buildDocumentsAndFlagsStep();
      default:
        return Center(child: Text("Step ${_step + 1}"));
    }
  }

  Widget _buildBasicInfoStep() {
    return _card([
      Text("Basic Information", style: Theme.of(context).textTheme.titleMedium),
      const Divider(),
      _text(
        'firm_name',
        'Firm Name',
        (v) => _formData['firm_name'] = v,
        required: true,
      ),
      // _text(
      //   'email',
      //   'Company Email',
      //   (v) => _formData['email'] = v,
      //   required: true,
      //   type: TextInputType.emailAddress,
      //   validator: (value) {
      //     if (value == null || value.isEmpty) return 'Required';
      //     final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      //     if (!emailRegex.hasMatch(value)) {
      //       return 'Enter a valid email address (e.g., name@example.com)';
      //     }
      //     return null;
      //   },
      // ),
      _text(
        'mobile_number',
        'Company Phone Number',
        (v) => _formData['mobile_number'] = v,
        required: true,
        type: TextInputType.phone,
        maxLength: 10,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (v) {
          if (v == null || v.isEmpty) return 'Required';
          if (v.length != 10) return 'Mobile number must be 10 digits';
          return null;
        },
      ),
      _text('rera_number', 'RERA Number', (v) => _formData['rera_number'] = v),


      _starRating('CP Quality'),
      

      _dropdown('type', 'Type', ['P1', 'P2', 'P3'], (v) {
        setState(() {
          _formData['type'] = v;
        });
      }, required: true),
      
      _multiSelect(
        'property_preferences',
        'Property Preferences',
        ['Under Construction', 'Ready to Move In', 'Resale'],
        (v) {
          setState(() {
            _formData['property_preferences'] = v.join(',');
          });
        },
        required: true,
      ),

      _dropdown('category', 'Category', ['Individual', 'Company'], (v) {
        setState(() {
          _formData['category'] = v;
        });
      }, required: true),
      
      _dropdown(
        'team_size',
        'Team Size',
        ['1 - 5', '5 - 10', '10 - 20', '20 - 50', '50+'],
        (v) {
          setState(() {
            _formData['team_size'] = v;
          });
        },
        required: true,
      ),
    ]);
  }

  Widget _starRating(String label) {
    return FormField<double>(
      initialValue: (_formData['cp_quality'] as num?)?.toDouble() ?? 0.0,
      validator: (v) => (v == null || v == 0.0) ? 'Required' : null,
      builder: (state) {
        int currentRating = ((state.value ?? 0.0) / 0.2).round();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: state.hasError
                    ? Colors.red.shade700
                    : Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (index) {
                int starValue = index + 1;
                bool isActive = starValue <= currentRating;
                return GestureDetector(
                  onTap: () {
                    final newVal = starValue * 0.2;
                    setState(() {
                      _formData['cp_quality'] = newVal;
                    });
                    state.didChange(newVal);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      isActive
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: isActive ? Colors.amber[600] : Colors.grey[300],
                      size: 32,
                    ),
                  ),
                );
              }),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  state.errorText!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStationPreferencesStep() {
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _stationPreferences.length,
          itemBuilder: (context, index) {
            final currentRoute = _stationPreferences[index]['railway_route'];
            final filteredStations =
                _railwayStations
                    .where((s) => s['route'] == currentRoute)
                    .map((s) => s['station_name']!)
                    .toSet()
                    .toList() // Remove duplicates if any
                  ..sort();

            return _card([
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Station Preference ${index + 1}",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red,
                    ),
                    onPressed: () {
                      setState(() {
                        _stationPreferences.removeAt(index);
                      });
                    },
                  ),
                ],
              ),
              const Divider(),
              _dynamicDropdown(
                'Railway Route',
                ['Western', 'Central', 'Harbour'],
                currentRoute,
                (v) {
                  setState(() {
                    _stationPreferences[index]['railway_route'] = v;
                    _stationPreferences[index]['from_station'] = null;
                    _stationPreferences[index]['to_station'] = null;
                  });
                },
              ),
              // const SizedBox(height: 16),
              _stationSelector(
                'From Station',
                _stationPreferences[index]['from_station'],
                filteredStations,
                (v) {
                  setState(() {
                    _stationPreferences[index]['from_station'] = v;
                  });
                },
                isLoading: _isFetchingStations,
                required: true,
              ),
              // const SizedBox(height: 16),
              _stationSelector(
                'To Station',
                _stationPreferences[index]['to_station'],
                filteredStations,
                (v) {
                  setState(() {
                    _stationPreferences[index]['to_station'] = v;
                  });
                },
                isLoading: _isFetchingStations,
                required: true,
              ),
            ]);
          },
        ),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _stationPreferences.add({
                'railway_route': 'Western',
                'from_station': null,
                'to_station': null,
              });
            });
          },
          icon: const Icon(Icons.add),
          label: const Text("Add Station Preference"),
        ),
      ],
    );
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
                  Text(
                    "Contact Person ${index + 1}",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red,
                    ),
                    onPressed: () {
                      setState(() {
                        _contactPersons.removeAt(index);
                      });
                    },
                  ),
                ],
              ),
              const Divider(),
              _text(
                'full_name_$index',
                'Full Name',
                (v) {},
                initialValue: _contactPersons[index]['full_name'],
                onChanged: (v) => _contactPersons[index]['full_name'] = v,
                required: true,
              ),
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
              _text(
                'mobile_$index',
                'Mobile',
                (v) {},
                initialValue: _contactPersons[index]['mobile'],
                onChanged: (v) => _contactPersons[index]['mobile'] = v,
                type: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                required: true,
              ),
              _text(
                'email_$index',
                'Email',
                (v) {},
                initialValue: _contactPersons[index]['email'],
                onChanged: (v) => _contactPersons[index]['email'] = v,
                type: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  final emailRegex = RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  );
                  if (!emailRegex.hasMatch(value)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
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
      Text(
        "Address & Location",
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const Divider(),
      _text(
        'full_address',
        'Full Address',
        (v) => _formData['full_address'] = v,
        required: true,
      ),
      _buildLocationWidget(),
    ]);
  }

  Widget _buildLocationWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Button removed as per request
            const Icon(Icons.location_on, color: Colors.grey),
            const SizedBox(width: 16),
            Expanded(
              child:
                  (_formData['location'] != null &&
                      _formData['location'].isNotEmpty)
                  ? const Icon(Icons.check_circle_outline, color: Colors.green)
                  : const Text(
                      'Location required',
                      style: TextStyle(fontSize: 12),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDocumentsAndFlagsStep() {
    return Column(
      children: [
        _card([
          Text(
            "Documents (currently not working)",
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red,
                    ),
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
          Text(
            "Property Flags (Select)",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Divider(),
          _buildFlags(),
        ]),
        _card([
          Text(
            "Operations & Status",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Divider(),
          _buildOperations(),
        ]),
        
      ],
    );
  }

  Future<void> _pickFile(int index) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    print("Picked file: ${pickedFile?.path}");
    if (pickedFile != null) {
      setState(() {
        _documents[index]['document_attachment'] = pickedFile.path;
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('File picking cancelled.')));
    }
  }

  Widget _buildOperations() {
    final flags = [
      {
        'key': 'does_digitalmarketing',
        'title': 'Does Digital Marketing',
        'icon': Icons.campaign_rounded,
      },
      {
        'key': 'aop_signed',
        'title': 'AOP Signed',
        'icon': Icons.verified_user_rounded,
      },
      {
        'key': 'gives_callingdata',
        'title': 'Gives Calling Data',
        'icon': Icons.contact_phone_rounded,
      },
    ];

    return Column(
      children: flags.map((flag) {
        final key = flag['key'] as String;
        final title = flag['title'] as String;
        final icon = flag['icon'] as IconData;
        final isActive = _formData[key] == 1;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isActive ? kAccent.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? kAccent.withOpacity(0.3) : Colors.grey.shade200,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() {
                  _formData[key] = isActive ? 0 : 1;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isActive
                            ? kAccent.withOpacity(0.1)
                            : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: isActive ? kAccent : Colors.grey.shade500,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isActive
                              ? Colors.black87
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: isActive,
                      activeColor: kAccent,
                      onChanged: (bool value) {
                        setState(() {
                          _formData[key] = value ? 1 : 0;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFlags() {
    final flags = [
      {'key': 'commercial', 'icon': Icons.business_center_rounded},
      {'key': 'luxury', 'icon': Icons.diamond_rounded},
      {'key': 'land', 'icon': Icons.landscape_rounded},
      {'key': 'redevelopment', 'icon': Icons.construction_rounded},
      {'key': 'residential', 'icon': Icons.home_rounded},
      {'key': 'retail', 'icon': Icons.storefront_rounded},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: flags.map((flag) {
        final key = flag['key'] as String;
        final icon = flag['icon'] as IconData;
        final title = key
            .replaceAll('_', ' ')
            .split(' ')
            .map((l) => l[0].toUpperCase() + l.substring(1))
            .join(' ');
        final isSelected = _formData[key] == 1;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              setState(() {
                _formData[key] = isSelected ? 0 : 1;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? kAccent : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? kAccent : Colors.grey.shade300,
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: kAccent.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _stationSelector(
    String label,
    String? value,
    List<String> items,
    Function(String) onSelected, {
    bool isLoading = false,
    bool required = false,
  }) {
    return FormField<String>(
      initialValue: value,
      validator: required
          ? (_) => (value == null || value.isEmpty) ? 'Required' : null
          : null,
      builder: (FormFieldState<String> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: isLoading
                  ? null
                  : () => _showSearchDialog(label, items, (v) {
                      onSelected(v);
                      state.didChange(v);
                    }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: state.hasError
                        ? Colors.red.shade700
                        : Colors.black12,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              color: state.hasError
                                  ? Colors.red.shade700
                                  : Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            value?.isNotEmpty == true
                                ? value!
                                : "Select Station",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: value?.isNotEmpty == true
                                  ? Colors.black87
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kAccent,
                        ),
                      )
                    else
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: Colors.black45,
                      ),
                  ],
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 16.0),
                child: Text(
                  state.errorText!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _dynamicDropdown(
    String label,
    List<String> items,
    String? currentValue,
    Function(String?) onChanged, {
    bool isLoading = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: currentValue,
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
              child: Text(value, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: isLoading ? null : onChanged,
        ),
      ],
    );
  }

  void _showSearchDialog(
    String label,
    List<String> items,
    Function(String) onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = items
                .where(
                  (i) =>
                      i != 'SEARCH_STATION' &&
                      i.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select $label',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.grey[400],
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey[100],
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: TextField(
                        autofocus: true,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search for a station...',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: kAccent,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 15,
                            horizontal: 20,
                          ),
                        ),
                        onChanged: (v) {
                          setSheetState(() {
                            query = v;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filtered.isEmpty
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 64,
                                color: Colors.grey[200],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No stations found',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const Divider(
                              height: 1,
                              indent: 60,
                              endIndent: 16,
                              color: Color(0xFFF1F1F1),
                            ),
                            itemBuilder: (context, index) {
                              final station = filtered[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: kAccent.withOpacity(0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.train_rounded,
                                    color: kAccent,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  station,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.grey[300],
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                onTap: () {
                                  onSelected(station);
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
    String? Function(String?)? validator,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      key: ValueKey(keyName),
      controller: controller,
      initialValue:
          initialValue ??
          (controller == null ? _formData[keyName]?.toString() : null),
      keyboardType: type,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: kInputDecoration.copyWith(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        counterText: "", // Hide the counter UI
      ),
      validator:
          validator ??
          (required ? (v) => v!.isEmpty ? 'Required' : null : null),
      onSaved: onSave,
      onChanged:
          onChanged ??
          (val) {
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
    bool required = false,
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
      validator: required
          ? (v) => (v == null || v.isEmpty) ? 'Required' : null
          : null,
      onChanged: isLoading ? null : onChange,
      onSaved: onChange,
    );
  }

  Widget _multiSelect(
    String keyName,
    String label,
    List<String> items,
    Function(List<String>) onChange, {
    bool required = false,
  }) {
    List<String> selectedItems =
        (_formData[keyName] as String?)
            ?.split(',')
            .where((e) => e.trim().isNotEmpty)
            .toList() ??
        [];

    return FormField<List<String>>(
      initialValue: selectedItems,
      validator:
          required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color:
                    state.hasError ? Colors.red.shade700 : Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 0,
              children: items.map((item) {
                final isSelected = selectedItems.contains(item);
                return FilterChip(
                  label: Text(
                    item,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: Theme.of(context).primaryColor,
                  checkmarkColor: Colors.white,
                  onSelected: (bool selected) {
                    if (selected) {
                      if (!selectedItems.contains(item)) {
                        selectedItems.add(item);
                      }
                    } else {
                      selectedItems.remove(item);
                    }
                    state.didChange(selectedItems);
                    onChange(selectedItems);
                  },
                );
              }).toList(),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  state.errorText!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
          ],
        );
      },
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
                onPressed: _isLoading
                    ? null
                    : () {
                        if (_formKey.currentState!.validate()) {
                          _formKey.currentState!.save();

                          // Custom validation for specific steps
                          if (_step == 2) {
                            // Contacts step
                            if (_contactPersons.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please add at least one contact person.',
                                  ),
                                ),
                              );
                              return;
                            }
                          }

                          if (_step == 4) {
                            // Documents & Flags step
                            final flags = [
                              'commercial',
                              'luxury',
                              'land',
                              'redevelopment',
                              'residential',
                              'retail',
                              'does_digitalmarketing',
                              'aop_signed',
                              'gives_callingdata',
                            ];
                            bool anyFlag = flags.any(
                              (flag) => _formData[flag] == 1,
                            );
                            if (!anyFlag) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please select at least one flag.',
                                  ),
                                ),
                              );
                              return;
                            }
                          }

                          if (_step < 4) {
                            setState(() => _step++);
                            _scrollToTop();
                          } else {
                            _submitForm();
                          }
                        }
                      },
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _step < 4 ? 'Next' : 'Submit',
                        style: const TextStyle(
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
