import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:latlong2/latlong.dart';
import 'package:tavo/core/constants/app_assets.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/helpers/utils/spacing.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const MapPickerScreen({super.key, this.initialLocation});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late final MapController _mapController;
  late LatLng _selectedLocation;
  String _locationName = '';
  bool _isLoadingAddress = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedLocation =
        widget.initialLocation ?? const LatLng(24.7136, 46.6753);
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedLocation = point;
      _locationName = '';
    });
    _reverseGeocode(point);
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _isLoadingAddress = true);
    try {
      final dio = Dio();
      dio.options.headers['User-Agent'] = 'tavo-app/1.0';
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': point.latitude,
          'lon': point.longitude,
          'format': 'json',
          'accept-language': 'ar',
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (mounted) {
        final address = data['address'] as Map<String, dynamic>?;
        final displayName = data['display_name'] as String?;
        if (address != null) {
          final parts = <String>[];
          if (address['road'] != null) parts.add(address['road']);
          if (address['neighbourhood'] != null) {
            parts.add(address['neighbourhood']);
          }
          if (address['city'] != null) {
            parts.add(address['city']);
          } else if (address['town'] != null) {
            parts.add(address['town']);
          } else if (address['state'] != null) {
            parts.add(address['state']);
          }
          setState(() {
            _locationName = parts.isNotEmpty
                ? parts.join('، ')
                : displayName ?? '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
          });
        } else if (displayName != null) {
          setState(() => _locationName = displayName);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationName =
              '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  void _onConfirm() {
    Navigator.of(context).pop((_selectedLocation, _locationName));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),
          _buildTopBar(context),
          _buildBottomContainer(context),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _selectedLocation,
        initialZoom: 15,
        onTap: _onTap,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.rasad.tavo',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: _selectedLocation,
              width: 40,
              height: 40,
              child: const Icon(
                Icons.location_on,
                color: ColorsManager.primaryColor,
                size: 40,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16.h,
      left: 16.w,
      right: 16.w,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 44.w,
              height: 44.h,
              decoration: BoxDecoration(
                color: ColorsManager.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(80.r),
              ),
              child: Center(
                child: Icon(
                  Icons.arrow_back,
                  size: 18.sp,
                  color: ColorsManager.black,
                ),
              ),
            ),
          ),
          horizontalSpace(12),
          Text(
            "اضافه موقع",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ColorsManager.black,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationName() {
    final hasLocation = _locationName.isNotEmpty;

    return Container(
      height: 48.h,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(80.r),
        border: Border.all(color: ColorsManager.lightGrey),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            AppAssets.map,
            width: 20.w,
            height: 20.h,
            color: hasLocation
                ? ColorsManager.primaryColor
                : ColorsManager.darkGray300,
          ),
          horizontalSpace(8),
          Expanded(
            child: Text(
              _isLoadingAddress
                  ? '...'
                  : hasLocation
                      ? _locationName
                      : 'location_name_hint'.tr(),
              style: TextStyle(
                fontSize: 14.sp,
                color: hasLocation && !_isLoadingAddress
                    ? ColorsManager.black
                    : ColorsManager.fontLightGrey,
                fontWeight: FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomContainer(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Positioned(
      bottom: 8.h,
      left: 8.w,
      right: 8.w,
      child: Container(
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: ColorsManager.white,
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            verticalSpace(8),
           
            verticalSpace(12),
            _buildLocationName(),
            verticalSpace(16),
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: MaterialButton(
                onPressed: _onConfirm,
                color: ColorsManager.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(80.r),
                ),
                elevation: 0,
                child: Text(
                  'confirm_location'.tr(),
                  style: textTheme.bodyMedium?.copyWith(
                    color: ColorsManager.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            verticalSpace(32),
          ],
        ),
      ),
    );
  }
}
