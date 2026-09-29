// lib/feature/restaurant/ui/screens/restaurant_map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';
import 'package:tavo/core/constants/app_assets.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/theme_extensions.dart';
import 'package:tavo/core/theme/text_styles.dart';

class RestaurantMapScreen extends StatelessWidget {
  final String title;
  final double lat;
  final double lng;

  const RestaurantMapScreen({
    super.key,
    required this.title,
    required this.lat,
    required this.lng,
  });

  @override
  Widget build(BuildContext context) {
    final pos = LatLng(lat, lng);

    return Scaffold(
  
      appBar: AppBar(
        backgroundColor: context.cardColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: TextStyles.font16Black500Weight(context).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: SvgPicture.asset(
            AppAssets.arrowRight,
            width: 20.r,
            height: 20.r,
            colorFilter: ColorFilter.mode(
              context.textPrimaryColor,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: pos,
          initialZoom: 15,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.rasad.tavo',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: pos,
                width: 40.r,
                height: 40.r,
                child: Icon(
                  Icons.location_on,
                  color: ColorsManager.primaryColor,
                  size: 40.r,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}