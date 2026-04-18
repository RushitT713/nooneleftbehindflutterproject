import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

import '../auth_service.dart';
import '../constants.dart';
import '../providers/trip_provider.dart';
import '../services/trip_service.dart';
import '../utils/page_transitions.dart';
import 'map_screen.dart';
import 'face_crop_screen.dart';

class JoinSetupScreen extends StatefulWidget {
  final String tripCode;

  const JoinSetupScreen({super.key, required this.tripCode});

  @override
  State<JoinSetupScreen> createState() => _JoinSetupScreenState();
}

class _JoinSetupScreenState extends State<JoinSetupScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  final AuthService _auth = AuthService();

  bool _isLoading = false;

  // --- CLOUDINARY CONFIGURATION ---
  // TODO: Replace 'your_actual_cloud_name_here' with your Cloudinary Cloud Name
  final cloudinary = CloudinaryPublic(
      'dygikcty7',
      'flutter_project',
      cache: false
  );

  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  int _currentVehicleIndex = 0;
  final TripService _tripService = TripService();

  // --- 1. Show Camera / Gallery Options ---
  Future<void> _showImageSourceOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: kPrimary),
              title: Text('Take a Photo', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary))),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: kAccentBlue),
              title: Text('Choose from Gallery', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary))),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. Pick the Image ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 90,
      );

      if (photo != null && mounted) {
        // Navigate to FaceCropScreen for face positioning
        final File? croppedFace = await Navigator.push<File>(
          context,
          SlideUpRoute<File>(
            page: FaceCropScreen(imageFile: File(photo.path)),
          ),
        );

        if (croppedFace != null) {
          setState(() {
            _profileImage = croppedFace;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to pick image: $e")),
        );
      }
    }
  }

  // --- 3. Upload to Cloudinary ---
  Future<String?> _uploadToCloudinary() async {
    if (_profileImage == null) return null;
    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(_profileImage!.path, folder: 'profile_pics'),
      );
      return response.secureUrl; // Returns the public URL of the uploaded image
    } catch (e) {
      print("Cloudinary Upload Error: $e");
      return null;
    }
  }

  void _nextVehicle() {
    setState(() {
      _currentVehicleIndex = (_currentVehicleIndex + 1) % kVehicles.length;
    });
  }

  void _prevVehicle() {
    setState(() {
      _currentVehicleIndex = (_currentVehicleIndex - 1 + kVehicles.length) % kVehicles.length;
    });
  }

  // --- 4. Join Convoy and Save Data ---
  Future<void> _joinConvoy() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty || nickname.length < kMinNicknameLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a nickname (min 2 chars)", style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (nickname.length > kMaxNicknameLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nickname too long (max 20 chars)", style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await _auth.signInAnonymously();
      if (user != null) {
        String? photoUrl = await _uploadToCloudinary();
        final vehicleName = kVehicles[_currentVehicleIndex].name;

        final tripModel = await _tripService.joinTrip(
          tripCode: widget.tripCode,
          userUid: user.uid,
          nickname: nickname,
          vehicleType: vehicleName,
          photoUrl: photoUrl,
        );

        if (mounted) {
          await context.read<TripProvider>().setTrip(
            userId: user.uid,
            tripCode: widget.tripCode,
            nickname: nickname,
            vehicleType: vehicleName,
            photoUrl: photoUrl,
            isHost: false,
            tripModel: tripModel,
          );

          Navigator.pushAndRemoveUntil(
            context,
            ScaleFadeRoute(page: const MapScreen()),
                (Route<dynamic> route) => false,
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error joining: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: kPrimary))
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 10),

              // --- HEADERS ---
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Join the Convoy",
                  style: theme.textTheme.displayMedium,
                ),
              ),
              SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Joining Trip: ${widget.tripCode}\nHow will others see you on the map?",
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              SizedBox(height: 30),

              // --- AVATAR WIDGET ---
              GestureDetector(
                onTap: _showImageSourceOptions,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomRight,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 160,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/images/paper_bg.png',
                              fit: BoxFit.cover,
                              width: 140,
                              height: 160,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(Icons.person, size: 80, color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary));
                              },
                            ),
                          ),
                          if (_profileImage != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.file(
                                _profileImage!,
                                width: 130,
                                height: 150,
                                fit: BoxFit.cover,
                              ),
                            )
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: -5,
                      right: -10,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kPrimary,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: kPrimary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Icon(Icons.camera_alt, size: 28, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 40),

              // --- NICKNAME INPUT ---
              Text(
                  "WHAT TO CALL YOURSELF?",
                  style: theme.textTheme.labelLarge?.copyWith(fontSize: 14, color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary))
              ),
              SizedBox(height: 8),
              TextField(
                controller: _nicknameController,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary)),
                decoration: InputDecoration(
                  hintText: "e.g., The Navigator",
                  hintStyle: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary).withValues(alpha: 0.5)),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder), width: 2),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: kPrimary, width: 3),
                  ),
                ),
              ),
              SizedBox(height: 50),

              // --- VEHICLE CAROUSEL ---
              Text(
                  "WHAT ARE YOU DRIVING?",
                  style: theme.textTheme.labelLarge?.copyWith(fontSize: 14, color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary))
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios, size: 40, color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextSecondary : kTextSecondary)),
                    onPressed: _prevVehicle,
                  ),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: Column(
                      key: ValueKey<int>(_currentVehicleIndex),
                      children: [
                        Image.asset(
                          kVehicles[_currentVehicleIndex].assetPath,
                          height: 130,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.directions_car, size: 130, color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextSecondary : kTextSecondary));
                          },
                        ),
                        SizedBox(height: 12),
                        Text(
                          kVehicles[_currentVehicleIndex].name,
                          style: theme.textTheme.labelLarge?.copyWith(color: kPrimary),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    icon: Icon(Icons.arrow_forward_ios, size: 40, color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextSecondary : kTextSecondary)),
                    onPressed: _nextVehicle,
                  ),
                ],
              ),

              SizedBox(height: 40),

              // --- ENTER MAP BUTTON ---
              ElevatedButton(
                onPressed: _joinConvoy,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  elevation: 0,
                ),
                child: Text("Enter Map", style: theme.textTheme.displayMedium?.copyWith(color: Colors.white)),
              ),
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}