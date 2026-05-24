import 'package:flutter/material.dart';
import 'package:Homesol/utils/custom_snackbar.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

import '../models/project.dart';
import '../models/lead.dart';
import '../utils.dart';
import '../services/auth_service.dart';
import '../services/image_cache_manager.dart';
import 'dart:convert';

const Color kAccent = Color(0xFF1A1A1A);

class ProjectShareBottomSheet extends StatefulWidget {
  final Project project;
  final Lead lead;

  const ProjectShareBottomSheet({super.key, required this.project, required this.lead});

  @override
  State<ProjectShareBottomSheet> createState() => _ProjectShareBottomSheetState();
}

class _ProjectShareBottomSheetState extends State<ProjectShareBottomSheet> {
  static const platform = MethodChannel('com.homesolindia.crm/whatsapp_share');
  bool _isLoading = true;
  bool _isDownloading = false;
  String _currentUserEmail = 'test@homesolindia.com';
  String _currentUserName = 'HomeSol Agent';
  String _currentUserPhone = '';

  bool _includeGeneralInfo = true;
  final Set<int> _selectedDocIndices = {};
  final Set<int> _selectedImageIndices = {};
  final Set<int> _selectedBrochureIndices = {};

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  Future<void> _loadUserEmail() async {
    final userData = await AuthService.getUserData();
    if (userData != null && userData['email'] != null) {
      if (mounted) {
        setState(() {
          _currentUserEmail = userData['email'];
        });
      }
    }
    try {
      final profile = await AuthService.getMyProfile();
      if (profile != null && mounted) {
        setState(() {
          _currentUserName = profile.employeeName.isNotEmpty 
            ? profile.employeeName 
            : (profile.firstName + (profile.lastName != null ? ' ${profile.lastName}' : ''));
          _currentUserPhone = profile.cellNumber ?? profile.emergencyPhoneNumber ?? _currentUserEmail;
        });
      }
    } catch (_) {}
  }

  String _formatBudget(int num) {
    if (num == 0) return '0';
    return '${(num / 10000000).toStringAsFixed(2)} Cr';
  }

  String _generateGeneralInfo() {
    final buffer = StringBuffer();
    final p = widget.project;

    if (p.locationDisplay.isNotEmpty) {
      buffer.writeln("💫Nestled in the Heart of ${p.locationDisplay}");
      buffer.writeln("");
    }
    buffer.writeln("${p.projectName} By HomeSol_ Gateway To your Shine & Happiness ✨\n");
    
    final confs = p.configurations.map((e) => e.name).toSet().join(" & ");
    if (confs.isNotEmpty) {
      buffer.writeln("✨ Spacious & Luxurious $confs Bedroom Vastu Compliant Apartments.\n");
    }

    buffer.writeln("📍 *Project USP:*");
    String usp = p.description.isNotEmpty && p.description.length < 150 
        ? stripHtml(p.description) 
        : "Gateway To your Shine & Happiness ✨";
    buffer.writeln("$usp\n");

    if (p.configurations.isNotEmpty) {
      buffer.writeln("📍 *Configuration & Pricing:*");
      for (var c in p.configurations) {
        buffer.writeln("- ${c.name}");
        buffer.writeln("${c.carpetArea} Sq.Ft - ${_formatBudget(c.price.toInt())}** Onwards \n");
      }
    }

    buffer.writeln("💸 Hassle-Free Flexible Payment Plan💸 📈\n");

    if (p.amenities.isNotEmpty) {
      buffer.writeln("📍 *Indulge in a Luxury Lifestyle Curated for you:* 😎");
      for (var a in p.amenities) {
        buffer.writeln("- ${a.data}");
      }
      buffer.writeln("");
    }

    if (p.reraId.isNotEmpty) {
      buffer.writeln("*RERA NO*");
      buffer.writeln("${p.reraId}\n");
    }

    if (p.location != null && p.location!.isNotEmpty) {
       buffer.writeln("📍 *Google Map* 🗾");
      if (p.location!.contains('http')) {
        buffer.writeln("${p.location}\n");
      } else if (p.location!.startsWith('{')) {
        try {
          final data = jsonDecode(p.location!);
          final coords = data['features'][0]['geometry']['coordinates'];
          buffer.writeln("https://www.google.com/maps/search/?api=1&query=${coords[1]},${coords[0]}\n");
        } catch (e) {
          buffer.writeln("https://www.google.com/maps/search/?api=1&query=${p.location}\n");
        }
      } else {
        buffer.writeln("https://www.google.com/maps/search/?api=1&query=${p.location}\n");
      }
    }

    buffer.writeln("Contact For any Inquiry");
    buffer.writeln("$_currentUserName / $_currentUserPhone");

    return buffer.toString().trim();
  }

  Future<void> _directWhatsAppMultiShare(String phone, List<String> filePaths, String text) async {
    try {
      await platform.invokeMethod('shareMultipleFiles', {
        'phoneNumber': phone,
        'filePaths': filePaths,
        'text': text,
      });
    } on PlatformException catch (e) {
      debugPrint("Native Multi-Share failed: ${e.message}");
      // Fallback to native share sheet
      final files = filePaths.map((p) => XFile(p)).toList();
      await Share.shareXFiles(files, text: text);
    }
  }

  Future<void> _shareSelected() async {
    setState(() => _isDownloading = true);
    List<XFile> filesToShare = [];

    final tempDir = await getTemporaryDirectory();

    Future<void> processFile(String url, String fileName) async {
      if (url.isEmpty) {
        debugPrint("processFile: Empty URL for $fileName");
        return;
      }
      try {
        debugPrint("processFile: Retrieving $url");
        // Get the cached path first using ImageCacheManager (which handles auth)
        final cachedPath = await ImageCacheManager.downloadAndCacheImage(url);
        
        if (cachedPath != null) {
          final cachedFile = File(cachedPath);
          if (await cachedFile.exists() && await cachedFile.length() > 0) {
            // Copy to temp directory for sharing with external apps
            // This ensures the file is in a globally accessible temp location
            final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9.]'), '_');
            final extension = path.extension(cachedPath);
            final tempPath = '${tempDir.path}/$safeName$extension';
            final tempFile = await cachedFile.copy(tempPath);
            
            filesToShare.add(XFile(tempFile.path));
            debugPrint("processFile: Copied to temp and added: ${tempFile.path}");
          } else {
            debugPrint("processFile: Cached file is empty or missing");
          }
        } else {
          debugPrint("processFile: Failed to get cached path for $url");
        }
      } catch (e) {
        debugPrint("Error processing $url: $e");
      }
    }

    try {
      // 1. Process all selected files
      for (int i in _selectedDocIndices) {
        final doc = widget.project.documents[i];
        final name = doc.documentName.isNotEmpty ? doc.documentName : 'Document_${i+1}';
        await processFile(doc.file, name);
      }
      for (int i in _selectedBrochureIndices) {
        final bro = widget.project.brochures[i];
        final name = bro.brochureName.isNotEmpty ? bro.brochureName : 'Brochure_${i+1}';
        await processFile(bro.file, name);
      }
      for (int i in _selectedImageIndices) {
        final img = widget.project.galleryImages[i];
        await processFile(img.images, 'Image_${i+1}');
      }

      // 2. Generate text
      String textToShare = "";
      if (_includeGeneralInfo) {
        textToShare = _generateGeneralInfo();
      }

      if (filesToShare.isEmpty && textToShare.isEmpty) {
        if (mounted) {
           CustomSnackBar.show(context, message: 'Please select something to share.', isError: false, title: 'Notice');
        }
        return;
      }

      // 3. Format phone
      String phone = (widget.lead.whatsappNo?.isNotEmpty == true) 
          ? widget.lead.whatsappNo! 
          : widget.lead.customerPhone;
      
      phone = phone.trim().replaceAll(RegExp(r'[^0-9]'), '');
      if (phone.startsWith('0')) phone = phone.substring(1);
      if (phone.length == 10) phone = '91$phone';

      // 4. Execute Sharing
      if (phone.isNotEmpty) {
        try {
          // Direct Multi-File Sharing (Native Bypass)
          if (filesToShare.isNotEmpty) {
             debugPrint("Invoking Native Multi-Share for: $phone");
             final paths = filesToShare.map((f) => f.path).toList();
             final caption = textToShare.isNotEmpty ? textToShare : "Project Documents";
             await _directWhatsAppMultiShare(phone, paths, caption);
             return;
          } 
          
          // Text-only Sharing
          else if (textToShare.isNotEmpty) {
            final whatsappUrl = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(textToShare)}");
            if (await canLaunchUrl(whatsappUrl)) {
              await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
              return;
            }
          }
        } catch (e) {
          debugPrint("Direct WhatsApp sharing failed: $e");
        }
      }

      // 5. Fallback: Use System Native Share Sheet
      if (filesToShare.isNotEmpty) {
        await Share.shareXFiles(filesToShare, text: textToShare.isNotEmpty ? textToShare : null);
      } else if (textToShare.isNotEmpty) {
        await Share.share(textToShare);
      }
    } catch (e) {
      debugPrint("Sharing error: $e");
      if (mounted) {
         CustomSnackBar.show(context, message: 'Error sharing: $e', isError: true, title: 'Error');
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  void _copyGeneralInfo() {
    if (_includeGeneralInfo) {
      Clipboard.setData(ClipboardData(text: _generateGeneralInfo()));
      CustomSnackBar.show(context, message: 'Copied to clipboard!', isError: false, title: 'Notice');
    } else {
      CustomSnackBar.show(context, message: 'General Information is not selected.', isError: false, title: 'Notice');
    }
  }

  Widget _buildSectionHeader(String title, bool isSelectedAll, VoidCallback onSelectAll) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          TextButton(
            onPressed: onSelectAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(isSelectedAll ? "Deselect All" : "Select All", style: const TextStyle(color: kAccent, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              height: 5,
              width: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.share, color: kAccent),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Share Project", 
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)
                    ),
                  ),
                  if (_isDownloading)
                    const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: kAccent),
                    )
                  else ...[
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        setState(() {
                          bool isAllSelected = _includeGeneralInfo && 
                            _selectedImageIndices.length == widget.project.galleryImages.length &&
                            _selectedBrochureIndices.length == widget.project.brochures.length &&
                            _selectedDocIndices.length == widget.project.documents.length;
                          
                          if (isAllSelected) {
                            _includeGeneralInfo = false;
                            _selectedImageIndices.clear();
                            _selectedBrochureIndices.clear();
                            _selectedDocIndices.clear();
                          } else {
                            _includeGeneralInfo = true;
                            _selectedImageIndices.addAll(List.generate(widget.project.galleryImages.length, (i) => i));
                            _selectedBrochureIndices.addAll(List.generate(widget.project.brochures.length, (i) => i));
                            _selectedDocIndices.addAll(List.generate(widget.project.documents.length, (i) => i));
                          }
                        });
                      },
                      child: Text(
                        (_includeGeneralInfo && 
                         _selectedImageIndices.length == widget.project.galleryImages.length &&
                         _selectedBrochureIndices.length == widget.project.brochures.length &&
                         _selectedDocIndices.length == widget.project.documents.length)
                            ? "Deselect All" : "Select All", 
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kAccent)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ],
              ),
            ),
            
            const Divider(height: 1, color: Colors.black12),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 20),
                children: [
                  const SizedBox(height: 8),
                  // General Info
                  CheckboxListTile(
                    activeColor: kAccent,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Row(
                      children: [
                        const Text("General Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: Colors.white,
                                surfaceTintColor: Colors.transparent,
                                title: const Text('Preview General Info'),
                                content: SingleChildScrollView(
                                  child: Text(_generateGeneralInfo(), style: const TextStyle(fontSize: 13)),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: kAccent)))
                                ],
                              ),
                            );
                          },
                          child: const Icon(Icons.info_outline, size: 20, color: kAccent),
                        ),
                      ],
                    ),
                    value: _includeGeneralInfo,
                    onChanged: (val) {
                      setState(() => _includeGeneralInfo = val ?? false);
                    },
                  ),

                  if (widget.project.galleryImages.isNotEmpty) ...[
                    const Divider(height: 1, color: Colors.black12),
                    _buildSectionHeader(
                      "Images", 
                      _selectedImageIndices.length == widget.project.galleryImages.length,
                      () {
                        setState(() {
                          if (_selectedImageIndices.length == widget.project.galleryImages.length) {
                            _selectedImageIndices.clear();
                          } else {
                            _selectedImageIndices.addAll(List.generate(widget.project.galleryImages.length, (i) => i));
                          }
                        });
                      }
                    ),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.project.galleryImages.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final img = widget.project.galleryImages[index];
                          final url = buildImageUrl(img.images);
                          final isSelected = _selectedImageIndices.contains(index);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) _selectedImageIndices.remove(index);
                                else _selectedImageIndices.add(index);
                              });
                            },
                            child: Container(
                              width: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isSelected ? kAccent : Colors.grey.shade200, width: isSelected ? 2 : 1),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: url,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    errorWidget: (context, url, error) => const Icon(Icons.image_not_supported, color: Colors.grey),
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(color: kAccent, shape: BoxShape.circle),
                                        child: const Icon(Icons.check, size: 14, color: Colors.white),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (widget.project.brochures.isNotEmpty) ...[
                    const Divider(height: 1, color: Colors.black12),
                    _buildSectionHeader(
                      "Brochures", 
                      _selectedBrochureIndices.length == widget.project.brochures.length,
                      () {
                        setState(() {
                          if (_selectedBrochureIndices.length == widget.project.brochures.length) {
                            _selectedBrochureIndices.clear();
                          } else {
                            _selectedBrochureIndices.addAll(List.generate(widget.project.brochures.length, (i) => i));
                          }
                        });
                      }
                    ),
                    ...List.generate(widget.project.brochures.length, (index) {
                        final bro = widget.project.brochures[index];
                        final name = bro.brochureName.isNotEmpty ? bro.brochureName : 'Brochure ${index + 1}';
                        return CheckboxListTile(
                          activeColor: kAccent,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          title: Row(
                            children: [
                               Icon(Icons.picture_as_pdf, color: kAccent.withOpacity(0.8), size: 22),
                               const SizedBox(width: 12),
                               Expanded(child: Text(name, style: const TextStyle(fontSize: 14))),
                            ]
                          ),
                          secondary: IconButton(
                            icon: const Icon(Icons.remove_red_eye, color: kAccent, size: 20),
                            onPressed: () async {
                              final url = buildImageUrl(bro.file);
                              final uri = Uri.parse(url);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                          ),
                          value: _selectedBrochureIndices.contains(index),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) _selectedBrochureIndices.add(index);
                              else _selectedBrochureIndices.remove(index);
                            });
                          }
                        );
                    }),
                  ],

                  if (widget.project.documents.isNotEmpty) ...[
                    const Divider(height: 1, color: Colors.black12),
                    _buildSectionHeader(
                      "Documents", 
                      _selectedDocIndices.length == widget.project.documents.length,
                      () {
                        setState(() {
                          if (_selectedDocIndices.length == widget.project.documents.length) {
                            _selectedDocIndices.clear();
                          } else {
                            _selectedDocIndices.addAll(List.generate(widget.project.documents.length, (i) => i));
                          }
                        });
                      }
                    ),
                    ...List.generate(widget.project.documents.length, (index) {
                        final doc = widget.project.documents[index];
                        final name = doc.documentName.isNotEmpty ? doc.documentName : 'Document ${index + 1}';
                        return CheckboxListTile(
                          activeColor: kAccent,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          title: Row(
                            children: [
                               Icon(Icons.insert_drive_file, color: kAccent.withOpacity(0.8), size: 22),
                               const SizedBox(width: 12),
                               Expanded(child: Text(name, style: const TextStyle(fontSize: 14))),
                            ]
                          ),
                          secondary: IconButton(
                            icon: const Icon(Icons.remove_red_eye, color: kAccent, size: 20),
                            onPressed: () async {
                              final url = buildImageUrl(doc.file);
                              final uri = Uri.parse(url);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                          ),
                          value: _selectedDocIndices.contains(index),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) _selectedDocIndices.add(index);
                              else _selectedDocIndices.remove(index);
                            });
                          }
                        );
                    }),
                  ],
                ],
              ),
            ),

            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy Info', style: TextStyle(fontSize: 13)),
                      onPressed: _copyGeneralInfo,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: kAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 18),
                      // FontAwesomeIcons.whatsapp can be used if font_awesome_flutter is imported, but standard Icons don't have it natively. Let's just state WhatsApp
                      label: _isDownloading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              'Share (${(_includeGeneralInfo ? 1 : 0) + _selectedImageIndices.length + _selectedBrochureIndices.length + _selectedDocIndices.length})',
                              style: const TextStyle(fontSize: 13)
                            ),
                      onPressed: _isDownloading ? null : _shareSelected,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
