import 'dart:async';
import 'dart:developer';

import 'package:bikeTrack/services/database_helper.dart';
import 'package:bikeTrack/services/track_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HistoryInfo extends StatefulWidget {
  @override
  _HistoryInfoState createState() => _HistoryInfoState();

  final int index;

  HistoryInfo({Key key, this.index}) : super(key: key);
}

const double CAMERA_ZOOM = 16;
const double CAMERA_TILT = 80;
const double CAMERA_BEARING = 30;

Set<Marker> _markers = Set<Marker>();

BitmapDescriptor sourceIcon;

PolylinePoints polylinePoints;

List<LatLng> polylineCoords = [];

String googleAPIKey = "AIzaSyCUWJ02dCx6IJEOHDQdD45Dc7zREMFynhQ";

Set<Polyline> _polylines = Set<Polyline>();

TrackInfo _trackInfo;

DatabaseHelper _dbHelper = DatabaseHelper.instance;

class _HistoryInfoState extends State<HistoryInfo> {
  Completer<GoogleMapController> _controller = Completer();

  @override
  void initState() {
    super.initState();

    _queryTrackInfo(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    final TrackInfo _trackInfo = ModalRoute.of(context).settings.arguments;
    return Scaffold(
      appBar: AppBar(
        title: Text("Track Info"),
      ),
      body: FutureBuilder(
          future: _queryTrackInfo(widget.index),
          builder: (BuildContext context, AsyncSnapshot<TrackInfo> snapshot) {
            if (snapshot.data == null) {
              return Container(
                child: Text("Loading"),
              );
            } else {
              LatLng SOURCE_LOCATION =
                  LatLng(snapshot.data.initPosLat, snapshot.data.initPosLng);

              LatLng FINAL_LOCATION =
                  LatLng(snapshot.data.fPosLat, snapshot.data.fPosLng);

              polylineCoords.add(SOURCE_LOCATION);
              polylineCoords.add(FINAL_LOCATION);

              CameraPosition intialCameraPosition = CameraPosition(
                  zoom: CAMERA_ZOOM,
                  tilt: CAMERA_TILT,
                  bearing: CAMERA_BEARING,
                  target: SOURCE_LOCATION);

              return Stack(children: <Widget>[
                GoogleMap(
                    initialCameraPosition: intialCameraPosition,
                    myLocationButtonEnabled: false,
                    compassEnabled: false,
                    tiltGesturesEnabled: false,
                    markers: _markers,
                    polylines: _polylines,
                    mapType: MapType.normal,
                    onMapCreated: (GoogleMapController controller) {
                      _controller.complete(controller);
                      showPinsOnMap(
                          snapshot.data.initPosLat,
                          snapshot.data.initPosLng,
                          snapshot.data.fPosLat,
                          snapshot.data.fPosLng);
                      /* updatePinOnMap(
                          snapshot.data.initPosLat,
                          snapshot.data.initPosLng,
                          snapshot.data.fPosLat,
                          snapshot.data.fPosLng); */
                    })
              ]);
            }
          }),
    );
  }

  void showPinsOnMap(double ilat, double ilng, flat, flng) {
    var pinPosition = LatLng(ilat, ilng);
    var finalPosition = LatLng(flat, flng);
    sourceIcon = BitmapDescriptor.defaultMarker;

    _markers.add(Marker(
        markerId: MarkerId('sourcePin'),
        position: pinPosition,
        icon: sourceIcon));

    _markers.add(Marker(
        markerId: MarkerId('finalPin'),
        position: finalPosition,
        icon: sourceIcon));
  }

  void setPolyLines(double ilat, double ilng, double flat, double flng) async {
    if (ilat != null && ilng != null && flat != null && flng != null) {
      log("IN POLYLINES");
      log(ilat.toString());
      log(ilng.toString());
      log(flat.toString());
      log(flng.toString());
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        googleAPIKey,
        PointLatLng(ilat, ilng),
        PointLatLng(flat, flng),
      );

      if (result.points.isNotEmpty) {
        result.points.forEach((PointLatLng point) {
          polylineCoords.add(LatLng(point.latitude, point.longitude));
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

  Future<TrackInfo> _queryTrackInfo(int index) async {
    _trackInfo = await _dbHelper.queryTrackInfo(index);
/*     log(_trackInfo.avgSpeed.toString());
    log(_trackInfo.distance.toString());
    log(_trackInfo.initPosLat.toString());
    log(_trackInfo.initPosLng.toString());
    log(_trackInfo.fPosLat.toString());
    log(_trackInfo.fPosLng.toString()); */
    return _trackInfo;
  }

  void updatePinOnMap(
      double ilat, double ilng, double flat, double flng) async {
    if (mounted) {
      setState(() {
        var pinPosition = LatLng(ilat, ilng);

        var finalPosition = LatLng(flat, flng);

        _markers.removeWhere((m) => m.markerId.value == 'sourcePin');
        _markers.add(Marker(
            markerId: MarkerId('sourcePin'),
            position: pinPosition,
            icon: sourceIcon));
        _markers.removeWhere((m) => m.markerId.value == 'finalPin');
        _markers.add(Marker(
            markerId: MarkerId('finalPin'),
            position: finalPosition,
            icon: sourceIcon));
      });
      setPolyLines(ilat, ilng, flat, flng);
    }
  }
}