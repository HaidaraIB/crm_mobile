import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/lead_location.dart';

const _cartoTileUrl =
    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

class LeadLocationMapPicker extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final void Function(double? latitude, double? longitude) onChanged;
  final bool readOnly;

  const LeadLocationMapPicker({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  State<LeadLocationMapPicker> createState() => _LeadLocationMapPickerState();
}

class _LeadLocationMapPickerState extends State<LeadLocationMapPicker> {
  final MapController _mapController = MapController();
  bool _locating = false;
  String? _locError;

  bool get _hasMarker =>
      widget.latitude != null && widget.longitude != null;

  LatLng get _center => _hasMarker
      ? LatLng(widget.latitude!, widget.longitude!)
      : const LatLng(defaultMapCenterLat, defaultMapCenterLng);

  double get _zoom => _hasMarker ? 16.0 : 12.0;

  String _t(String key, String fallback) {
    return AppLocalizations.of(context)?.translate(key) ?? fallback;
  }

  @override
  void didUpdateWidget(LeadLocationMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _moveMapToCenter();
    }
  }

  void _moveMapToCenter() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(_center, _zoom);
      } catch (_) {}
    });
  }

  void _clear() {
    setState(() => _locError = null);
    widget.onChanged(null, null);
  }

  Future<void> _useMyLocation() async {
    setState(() {
      _locating = true;
      _locError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locError = _t('locationServicesDisabled', 'Location services disabled');
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _locError = _t('locationPermissionDenied', 'Location permission denied');
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      if (!widget.readOnly) {
        widget.onChanged(position.latitude, position.longitude);
      }
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        16,
      );
    } catch (_) {
      setState(() {
        _locError = _t('employeeLocationRequired', 'Could not get location');
      });
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (widget.readOnly) return;
    setState(() => _locError = null);
    widget.onChanged(point.latitude, point.longitude);
    _mapController.move(point, 16);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mapHeight = widget.readOnly ? 220.0 : 280.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.readOnly
              ? _t('leadLocation', "Lead's location")
              : _t('setLeadLocationOnMap', 'Set location on map'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _locating ? null : _useMyLocation,
              icon: _locating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, size: 18),
              label: Text(
                _locating
                    ? _t('gettingLocation', 'Getting location…')
                    : _t('useMyLocation', 'Use my location'),
              ),
            ),
            if (!widget.readOnly && _hasMarker)
              OutlinedButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.clear, size: 18),
                label: Text(_t('clearLeadLocation', 'Clear location')),
              ),
          ],
        ),
        if (_locError != null) ...[
          const SizedBox(height: 8),
          Text(
            _locError!,
            style: TextStyle(color: Colors.red[700], fontSize: 13),
          ),
        ],
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: mapHeight,
            width: double.infinity,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: _zoom,
                interactionOptions: InteractionOptions(
                  flags: widget.readOnly
                      ? InteractiveFlag.none
                      : InteractiveFlag.all,
                ),
                onTap: _onMapTap,
                onMapReady: _moveMapToCenter,
              ),
              children: [
                TileLayer(
                  urlTemplate: _cartoTileUrl,
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.loopcrm.mobile',
                  maxZoom: 20,
                ),
                if (_hasMarker)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(widget.latitude!, widget.longitude!),
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.location_on,
                          color: AppTheme.primaryColor,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (_hasMarker) ...[
          const SizedBox(height: 6),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '${widget.latitude!.toStringAsFixed(6)}, ${widget.longitude!.toStringAsFixed(6)}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
