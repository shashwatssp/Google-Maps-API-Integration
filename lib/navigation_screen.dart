import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:math' show cos, sqrt, asin;

class NavigationScreen extends StatefulWidget {
  final double sourceLat;
  final double sourceLng;
  final double destLat;
  final double destLng;

  const NavigationScreen(
    this.sourceLat,
    this.sourceLng,
    this.destLat,
    this.destLng,
  );

  @override
  _NavigationScreenState createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final Set<Polyline> _polylines = {};
  final PolylinePoints _polylinePoints = PolylinePoints();
  final List<LatLng> _polylineCoordinates = [];
  LatLng _sourceLocation = const LatLng(0, 0);
  LatLng _destinationLocation = const LatLng(0, 0);

  Marker _sourceMarker = Marker(
    markerId: const MarkerId('source'),
    position: const LatLng(0, 0),
    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
    infoWindow: const InfoWindow(title: 'Source'),
  );

  Marker _destinationMarker = const Marker(
    markerId: MarkerId('destination'),
    position: LatLng(0, 0),
    icon: BitmapDescriptor.defaultMarker,
    infoWindow: InfoWindow(title: 'Destination'),
  );

  @override
  void initState() {
    super.initState();
    _sourceLocation = LatLng(widget.sourceLat, widget.sourceLng);
    _destinationLocation = LatLng(widget.destLat, widget.destLng);
    _sourceMarker = _sourceMarker.copyWith(positionParam: _sourceLocation);
    _destinationMarker =
        _destinationMarker.copyWith(positionParam: _destinationLocation);
    getPolylineCoordinates();
  }

  void getPolylineCoordinates() async {
    PolylineResult result = await _polylinePoints.getRouteBetweenCoordinates(
      "API-KEY",
      PointLatLng(widget.sourceLat, widget.sourceLng),
      PointLatLng(widget.destLat, widget.destLng),
      travelMode: TravelMode.driving,
    );

    if (result.points.isNotEmpty) {
      result.points.forEach((PointLatLng point) {
        _polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
    }

    setState(() {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('poly'),
          color: Colors.blue,
          points: _polylineCoordinates,
          width: 5,
        ),
      );
    });
  }

  void _onCameraMove(CameraPosition position) {
    setState(() {
      _sourceMarker = _sourceMarker.copyWith(positionParam: position.target);
      updateSourceMarker(position.target);
    });
  }

  void updateSourceMarker(LatLng newLocation) {
    double minDistance = double.infinity;

    for (LatLng coordinate in _polylineCoordinates) {
      double distance = calculateDistance(coordinate, _sourceLocation);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    if (minDistance >= 0.5) {
      _sourceLocation = newLocation;
      _polylineCoordinates.clear();
      _polylines.clear();
      setState(() {
        updatePath();
      });
    } else {
      _sourceLocation = newLocation;
    }
  }

  double calculateDistance(LatLng point1, LatLng point2) {
    const double p = 0.017453292519943295;
    final double a = 0.5 -
        cos((point2.latitude - point1.latitude) * p) / 2 +
        cos(point1.latitude * p) *
            cos(point2.latitude * p) *
            (1 - cos((point2.longitude - point1.longitude) * p)) /
            2;
    return 12742 * asin(sqrt(a));
  }

  void updatePath() async {
    _polylines.clear(); // Clear previous polylines

    PolylineResult result = await _polylinePoints.getRouteBetweenCoordinates(
      "API-KEY",
      PointLatLng(_sourceLocation.latitude, _sourceLocation.longitude),
      PointLatLng(
          _destinationLocation.latitude, _destinationLocation.longitude),
      travelMode: TravelMode.driving,
    );

    _polylineCoordinates.clear(); // Clear previous coordinates

    if (result.points.isNotEmpty) {
      result.points.forEach((PointLatLng point) {
        _polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
    }

    setState(() {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('poly'),
          color: Colors.blue,
          points: _polylineCoordinates,
          width: 5,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: CameraPosition(
              target: _sourceLocation,
              zoom: 14,
            ),
            polylines: _polylines,
            markers: Set<Marker>.of([_sourceMarker, _destinationMarker]),
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            onCameraMove: _onCameraMove,
          ),
          Positioned(
            top: 30,
            left: 15,
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: const Icon(Icons.arrow_back),
            ),
          ),
        ],
      ),
    );
  }
}
