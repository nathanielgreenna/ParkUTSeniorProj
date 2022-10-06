// Copyright 2019 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart';

import 'api_key.dart';
import 'firebase_options.dart';

// Center of the Google Map
const initialPosition = LatLng(41.658183, -83.615252);
// Hue used by the Google Map Markers to match the theme
const _greenHue = 120.0;
const _yellowHue = 30.0;
const _redHue = 0.0;
// Places API client used for Place Photos
final _placesApiClient = GoogleMapsPlaces(apiKey: googleMapsApiKey);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ice Creams FTW',
      home: const HomePage(title: 'ParkUT'),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({required this.title, super.key});
  final String title;

  @override
  State<StatefulWidget> createState() {
    return _HomePageState();
  }
}

class _HomePageState extends State<HomePage> {
  late Stream<QuerySnapshot> _iceCreamStores;
  final Completer<GoogleMapController> _mapController = Completer();

  @override
  void initState() {
    super.initState();
    _iceCreamStores = FirebaseFirestore.instance
        .collection('ParkingPlaces')
        .orderBy('name')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _iceCreamStores,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Loading...'));
          }

          return Stack(
            children: [
              StoreMap(
                documents: snapshot.data!.docs,
                initialPosition: initialPosition,
                mapController: _mapController,
              ),
              StoreCarousel(
                mapController: _mapController,
                documents: snapshot.data!.docs,
              ),
            ],
          );
        },
      ),
    );
  }
}

class StoreCarousel extends StatelessWidget {
  const StoreCarousel({
    super.key,
    required this.documents,
    required this.mapController,
  });

  final List<DocumentSnapshot> documents;
  final Completer<GoogleMapController> mapController;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: SizedBox(
          height: 90,
          child: StoreCarouselList(
            documents: documents,
            mapController: mapController,
          ),
        ),
      ),
    );
  }
}

class StoreCarouselList extends StatelessWidget {
  const StoreCarouselList({
    super.key,
    required this.documents,
    required this.mapController,
  });

  final List<DocumentSnapshot> documents;
  final Completer<GoogleMapController> mapController;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: documents.length,
      itemBuilder: (context, index) {
        return SizedBox(
          width: 180,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Card(
              child: Center(
                child: StoreListTile(
                  document: documents[index],
                  mapController: mapController,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class StoreListTile extends StatefulWidget {
  const StoreListTile({
    super.key,
    required this.document,
    required this.mapController,
  });

  final DocumentSnapshot document;
  final Completer<GoogleMapController> mapController;

  @override
  State<StatefulWidget> createState() {
    return _StoreListTileState();
  }
}

class _StoreListTileState extends State<StoreListTile> {
  String _placePhotoUrl = '';
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _retrievePlacesDetails();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _retrievePlacesDetails() async {}

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.document['name'] as String),
      subtitle: Text(
          '${((widget.document['spotsfilled'] / widget.document['capacity']) * 100).toStringAsFixed(0)}% Full | ${widget.document['capacity']} Total'),
      onTap: () async {
        final controller = await widget.mapController.future;
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(
                widget.document['coords'].latitude as double,
                widget.document['coords'].longitude as double,
              ),
              zoom: 16,
            ),
          ),
        );
      },
    );
  }
}

class StoreMap extends StatelessWidget {
  const StoreMap({
    super.key,
    required this.documents,
    required this.initialPosition,
    required this.mapController,
  });

  final List<DocumentSnapshot> documents;
  final LatLng initialPosition;
  final Completer<GoogleMapController> mapController;

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: initialPosition,
        zoom: 15,
      ),
      markers: documents
          .map((document) => Marker(
                markerId: MarkerId(document.id),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    (((document['spotsfilled'] / document['capacity'])
                                as double) >=
                            0.85)
                        ? _redHue
                        : ((((document['spotsfilled'] / document['capacity'])
                                    as double) >=
                                0.50)
                            ? _yellowHue
                            : _greenHue)),
                position: LatLng(
                  document['coords'].latitude as double,
                  document['coords'].longitude as double,
                ),
                infoWindow: InfoWindow(
                  title: document['name'] as String?,
                  snippet:
                      '${((document['spotsfilled'] / document['capacity']) * 100).toStringAsFixed(0)}% occupied',
                ),
              ))
          .toSet(),
      onMapCreated: (mapController) {
        this.mapController.complete(mapController);
      },
    );
  }
}
