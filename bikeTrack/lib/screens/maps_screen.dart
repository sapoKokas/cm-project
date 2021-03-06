import 'dart:developer';

import 'package:bikeTrack/services/database_helper.dart';
import 'package:bikeTrack/services/track_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'dart:async';

class MapsScreen extends StatefulWidget {
  static const routeName = '/maps';
  @override
  _MapsScreen createState() => _MapsScreen();
}

const double CAMERA_ZOOM = 16;
const double CAMERA_TILT = 80;
const double CAMERA_BEARING = 30;
const LatLng SOURCE_LOCATION = LatLng(42.747932, -71.167889);

class _MapsScreen extends State<MapsScreen> with AutomaticKeepAliveClientMixin {
  Completer<GoogleMapController> _controller = Completer();

  Set<Marker> _markers = Set<Marker>();

  Set<Polyline> _polylines = Set<Polyline>();

  List<LatLng> polylineCoords = [];

  List<LatLng> distanceReg = [];

  PolylinePoints polylinePoints;

  String googleAPIKey = "AIzaSyCUWJ02dCx6IJEOHDQdD45Dc7zREMFynhQ";

  BitmapDescriptor sourceIcon;

  BitmapDescriptor destinationIcon;

  LocationData initialposition;

  LocationData currentLocation;

  LocationData destinationLocation;

  Location location;

  bool _buttonPressed = false;

  StreamSubscription _locationSubscription;

  List<double> _speeds = List<double>();

  double _avgSpd = 0;

  double _totalDistance = 0;

  DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<LocationData> _future;

  @override
  void initState() {
    super.initState();

    location = new Location();

    polylinePoints = PolylinePoints();

    setSourceAndDestinationIcons();

    _future = setInitialLocation();
  }

  @override
  void dispose() {
    if (_locationSubscription != null) {
      _locationSubscription.cancel();
    }
    super.dispose();
  }

  void _listenLocation() {
    _locationSubscription =
        location.onLocationChanged.listen((LocationData cLoc) {
      initialposition = currentLocation;
      currentLocation = cLoc;
      if (currentLocation.speed != null) {
        _speeds.add(currentLocation.speed);
      }
      _calculateDistance();
      _calculateAvgSpeed();
      updatePinOnMap();
    });
  }

  void setSourceAndDestinationIcons() async {
    sourceIcon = BitmapDescriptor.defaultMarker;

    destinationIcon = BitmapDescriptor.defaultMarker;
  }

  Future<LocationData> setInitialLocation() async {
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return null;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return null;
      }
    }
    initialposition = await location.getLocation();

    currentLocation = await location.getLocation();

    return currentLocation;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    CameraPosition initialCameraPosition;

    return Scaffold(
      body: FutureBuilder(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<LocationData> snapshot) {
          if (snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    backgroundColor: Colors.blue,
                  ),
                  SizedBox(height: 20),
                  Text("Loading current location..."),
                ],
              ),
            );
          } else {
            initialCameraPosition = CameraPosition(
                target: LatLng(snapshot.data.latitude, snapshot.data.longitude),
                zoom: CAMERA_ZOOM,
                tilt: CAMERA_TILT,
                bearing: CAMERA_BEARING);
            return Stack(children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 0),
                child: GoogleMap(
                    myLocationButtonEnabled: false,
                    compassEnabled: false,
                    tiltGesturesEnabled: false,
                    markers: _markers,
                    polylines: _polylines,
                    mapType: MapType.normal,
                    initialCameraPosition: initialCameraPosition,
                    onMapCreated: (GoogleMapController controller) {
                      _controller.complete(controller);
                      showPinsOnMap();
                      updatePinOnMap();
                    }),
              ),
              Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(
                          Radius.circular(20.0),
                        ),
                      ),
                      width: MediaQuery.of(context).size.width * 0.95,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Row(
                                children: [
                                  Expanded(
                                    child: RaisedButton(
                                      onPressed: _setLocationListening,
                                      color: Colors.amber,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: Text("Start/Stop Tracking"),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: RaisedButton(
                                      onPressed: () {
                                        if (_buttonPressed) {
                                          showDialog(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return AlertDialog(
                                                  title: Text(
                                                      "Could not save the track"),
                                                  content: Text(
                                                      "Please stop the tracking before trying to save"),
                                                  actions: [
                                                    FlatButton(
                                                        onPressed: () {
                                                          Navigator.pop(
                                                              context);
                                                        },
                                                        child: Text("Ok"))
                                                  ],
                                                );
                                              });
                                        } else {
                                          _saveToDB();
                                        }
                                      },
                                      color: Colors.amber,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: Text("Save"),
                                    ),
                                  ),
                                  Expanded(
                                    child: RaisedButton(
                                      onPressed: _reset,
                                      color: Colors.amber,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: Text("Reset"),
                                    ),
                                  ),
                                ],
                              ),

                              /*  Text("Average Speed: " + _avgSpd.toString()),
                              Text("Distance: $_totalDistance"), */
                            ],
                          ),
                        ),
                      ),
                    ),
                  ))
            ]);
          }
        },
      ),
    );
  }

  void _setLocationListening() {
    _buttonPressed = !_buttonPressed;
    if (_buttonPressed) {
      _listenLocation();
      polylineCoords.clear();
      _polylines.clear();
    } else {
      _locationSubscription.cancel();
    }
    log(_buttonPressed.toString());
  }

  void showPinsOnMap() {
    if (currentLocation != null) {
      var pinPosition =
          LatLng(currentLocation.latitude, currentLocation.longitude);

      _markers.add(Marker(
          markerId: MarkerId('sourcePin'),
          position: pinPosition,
          icon: sourceIcon));
    }
  }

  void setPolyLines() async {
    if (currentLocation != null && initialposition != null) {
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        googleAPIKey,
        PointLatLng(initialposition.latitude, initialposition.longitude),
        PointLatLng(currentLocation.latitude, currentLocation.longitude),
      );

      if (result.points.isNotEmpty) {
        result.points.forEach((PointLatLng point) {
          polylineCoords.add(LatLng(point.latitude, point.longitude));
          distanceReg.add(LatLng(point.latitude, point.longitude));
        });
        if (mounted) {
          setState(() {
            _polylines.add(Polyline(
                width: 5, // set the width of the polylines
                polylineId: PolylineId("poly"),
                color: Color.fromARGB(255, 40, 122, 198),
                points: polylineCoords));
          });
        }
      }
    }
  }

  void updatePinOnMap() async {
    if (mounted) {
      CameraPosition cPosition = CameraPosition(
        zoom: CAMERA_ZOOM,
        tilt: CAMERA_TILT,
        bearing: CAMERA_BEARING,
        target: LatLng(currentLocation.latitude, currentLocation.longitude),
      );

      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(cPosition));

      setState(() {
        var pinPosition =
            LatLng(currentLocation.latitude, currentLocation.longitude);

        _markers.removeWhere((m) => m.markerId.value == 'sourcePin');
        _markers.add(Marker(
            markerId: MarkerId('sourcePin'),
            position: pinPosition,
            icon: sourceIcon));
      });
      setPolyLines();
    }
  }

  void _calculateAvgSpeed() {
    _speeds.forEach((double element) {
      _avgSpd += element;
    });
    _avgSpd = (_avgSpd / _speeds.length) * 3.6;
  }

  void _calculateDistance() {
    for (int i = 0; i < distanceReg.length - 1; i++) {
      _totalDistance += Geolocator.distanceBetween(
          distanceReg[i].latitude,
          distanceReg[i].longitude,
          distanceReg[i + 1].latitude,
          distanceReg[i + 1].longitude);
    }
    distanceReg.clear();
  }

  void _saveToDB() async {
    TrackInfo trackInfo = TrackInfo();
    trackInfo.avgSpeed = _avgSpd;
    trackInfo.distance = _totalDistance;
    trackInfo.initPosLat = polylineCoords[0].latitude;
    trackInfo.initPosLng = polylineCoords[0].longitude;
    trackInfo.fPosLat = polylineCoords[polylineCoords.length - 1].latitude;
    trackInfo.fPosLng = polylineCoords[polylineCoords.length - 1].longitude;
    int id = await _dbHelper.insert(trackInfo);
    _reset();
  }

  void _reset() {
    setState(() {
      polylineCoords.clear();
      _polylines.clear();
      _avgSpd = 0;
      _totalDistance = 0;
    });
  }

  @override
  bool get wantKeepAlive => true;
}
