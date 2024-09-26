library gps_tracker_db;

import 'dart:async';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

// Class to manage the database
class DatabaseHelper {

  static final List <String> createTables = [
    "CREATE TABLE walk(" +
        "id              INTEGER PRIMARY KEY," +
        "name            TEXT UNIQUE," +
        "create_date     TEXT," +
        "status          INTEGER," +
        "optimum_minutes INTEGER," +
        "optimum_seconds INTEGER)",
    "CREATE TABLE walk_track(" +
        "id           INTEGER PRIMARY KEY," +
        "walk_id      INTEGER REFERENCES walk(id)," +
        "create_date  TEXT," +
        "latitude     REAL," +
        "longitude    REAL," +
        "distance     REAL," +
        "provider     TEXT," +
        "accuracy     REAL," +
        "elapsed_time LONG)",
    "CREATE TABLE walk_image(" +
        "id          INTEGER PRIMARY KEY," +
        "walk_id     INTEGER REFERENCES walk(id)," +
        "image_name  TEXT," +
        "create_date TEXT," +
        "latitude    REAL," +
        "distance    REAL," +
        "longitude   REAL)",
    "CREATE TABLE walk_waypoint(" +
        "id          INTEGER PRIMARY KEY," +
        "walk_id     INTEGER REFERENCES walk(id)," +
        "latitude    REAL," +
        "longitude   REAL)"
  ];

  static final List <String> dropTables = [
    "DROP TABLE IF EXISTS walk_waypoint",
    "DROP TABLE IF EXISTS walk_track",
    "DROP TABLE IF EXISTS walk_image",
    "DROP TABLE IF EXISTS walk"
  ];

  static final String insertWalk = "INSERT INTO walk(name,create_date,optimum_minutes,optimum_seconds) VALUES(?,?,0,0)";
  static final String updateWalkOptimumDuration = "UPDATE walk SET optimum_minutes = ?, optimum_seconds = ? WHERE name = ?";
  static final String getWalkDetails = "SELECT create_date, optimum_minutes, optimum_seconds " +
      "FROM walk WHERE name = ?";
  static final String getDistance = "SELECT MAX(wt.distance) AS distance " +
      "FROM walk w, walk_track wt WHERE w.name = ? AND wt.walk_id = w.id";
  // static final String getWalkDetails =
  //     "SELECT w.create_date AS create_date, w.optimum_minutes AS optimum_minutes, w.optimum_seconds AS optimum_seconds, MAX(wt.distance) AS distance " +
  //     "FROM walk w, walk_track wt "
  //     "WHERE w.name = ? AND wt.walk_id = w.id";
  static final String insertWalkTrackPoint =
      "INSERT INTO walk_track(walk_id,create_date,latitude,longitude,distance,accuracy,provider,elapsed_time) " +
          "SELECT id,?,?,?,?,?,?,? " +
          "FROM walk WHERE name = ?";
  static final String insertWalkImage =
      "INSERT INTO walk_image(walk_id,image_name,create_date,latitude,longitude,distance) " +
          "SELECT id,?,?,?,?,? " +
          "FROM walk WHERE name = ?";
  static final String insertWalkWaypoint =
      "INSERT INTO walk_waypoint(walk_id,latitude,longitude) " +
          "SELECT id,?,? " +
          "FROM walk WHERE name = ?";
  static final String deleteWalkWaypoints =
      "DELETE FROM walk_waypoint " +
          "WHERE walk_id = ?";

  static final List<String> deleteWalkStatements = [
    deleteWalkWaypoints,
    "DELETE FROM walk_track " +
        "WHERE walk_id = ?",
    "DELETE FROM walk_image " +
        "WHERE walk_id = ?",
    "DELETE FROM walk " +
        "WHERE id = ?"
  ];

  static final String getWalkId = "SELECT id AS id FROM walk WHERE name = ?";
  static final String getWalks = "SELECT name FROM walk";
  static final String getWalkTrack =
      "SELECT id,create_date,latitude,longitude,distance,accuracy,provider,elapsed_time " +
          "FROM walk_track " +
          "WHERE walk_id = (SELECT id FROM walk WHERE name = ?)" +
          "ORDER BY id";
  static final String getWalkImages =
      "SELECT image_name,create_date,latitude,longitude,distance " +
          "FROM walk_image " +
          "WHERE walk_id = (SELECT id FROM walk WHERE name = ?)" +
          "ORDER BY id";
  static final String getWalkWaypoints =
      "SELECT id,latitude,longitude " +
          "FROM walk_waypoint " +
          "WHERE walk_id = (SELECT id FROM walk WHERE name = ?)" +
          "ORDER BY id";
  static final String renameWalk =
      "UPDATE walk " +
          "SET name = ? " +
          "WHERE name = ?";
  static final String checkWalkForRename =
      "SELECT '1' AS identifier, COUNT(*) AS count "
          "FROM walk "
          "WHERE name = ? " +
          "UNION " +
          "SELECT '2' AS identifier, COUNT(*) AS count "
              "FROM walk "
              "WHERE name = ? ";

  static final _databaseName = "CrossCountryCourseCompanion.db";
  static final _databaseVersion = 1;
  var database;

  DatabaseHelper(String path) {

    database = openDatabase(
      // Set the path to the database. Note: Using the `join` function from the
      // `path` package is best practice to ensure the path is correctly
      // constructed for each platform.
        join(path, _databaseName),

        // When the database is first created, create the tables.
        onCreate: (db, version) {
          for (String s in createTables) {
            db.execute(s);
          }
        },
        version: _databaseVersion
    );
  }

  static Future<DatabaseHelper> getDatabaseHelper() async
  {
    WidgetsFlutterBinding.ensureInitialized();
    String path = await getDatabasesPath();
    return DatabaseHelper(path);
  }

  // Get a list of walks
  Future <List<String>> walks() async {
    final db = await database;

    // Query the table for all the walks
    final List<Map<String, dynamic>> maps = await db.query('walk');
    return List.generate(maps.length, (i) {
      return maps[i]['name'];
    });
  }

  // Add a new walk
  Future<void> addWalk(String name) async {
    Database db = await database;
    List results = await db.rawQuery(getWalkId, [name]);
    if (results.isNotEmpty) {
      throw Exception("Walk $name already exists");
    }
    try {
      String formattedDate = DateFormat('dd-MM-yyyy HH:mm:ss').format(
          DateTime.now());
      await db.execute(insertWalk,[name, formattedDate]);
    } catch (err) {
      throw Exception("Walk $name cannot be created");
    }
  }

// Rename a walk
  Future<void> updateWalkName (oldName, newName) async {
    Database db = await database;

    int numNewName = -1;
    int numOldName = -1;
    List results = await db.rawQuery(checkWalkForRename, [newName,oldName]);
    for (var row in results) {
      if (row["identifier"] == "1") {
        numNewName = row["count"];
      } else {
        numOldName = row["count"];
      }
    }
    if (numOldName != 1) {
      throw Exception("Walk $oldName does not exist");
    }
    if (numNewName != 0) {
      throw Exception("Walk $newName already exists");
    }
    try {
      await db.execute(renameWalk, [newName, oldName]);
    } catch (err) {
      throw Exception("Walk $oldName cannot be renamed");
    }
  }

  // Delete a walk
  Future<void> deleteWalk (name) async {
    Database db = await database;
    List results = await db.rawQuery(getWalkId, [name]);
    if (results.isEmpty) {
      throw Exception("Walk $name does not exist");
    }
    int id = results[0]["id"];
    await db.transaction((txn) async {
      for (var statement in deleteWalkStatements)
      {
        await txn.execute(statement,[id]);
      }
    });
  }

  // Retrieve a specific walk
  //      getWalkTrack
  //      getWalkImages
  //      getWalkWaypoints
  Future<Walk> getWalk(String walkName) async {
    Database db = await database;
    var walk = null;
    var num_walks = 0;

    try {
      List results = await db.rawQuery(getWalkDetails, [walkName]);
      num_walks = results.length;
      if (num_walks == 1) {
        // walk = new Walk(name: walkName);
        walk = new Walk(
          name: walkName,
          create_date: results[0]["create_date"],
          optimum_minutes: results[0]["optimum_minutes"],
          optimum_seconds: results[0]["optimum_seconds"],
        );
        walk.track = <WalkTrackPoint>[];
        walk.waypoints = <WalkWaypoint>[];
        walk.images = <WalkImage>[];
      }
    } catch (err) {
      print(err);
      throw Exception("Walk '$walkName' cannot be retrieved");
    }
    if (num_walks != 1) {
      throw Exception("Walk '$walkName' does not exist");
    }

    try {
      List results = await db.rawQuery(getWalkTrack, [walkName]);
      for (var row in results) {
        WalkTrackPoint wtp = new WalkTrackPoint(
            create_date: row['create_date'],
            latitude: row['latitude'],
            longitude: row['longitude'],
            distance: row['distance'],
            accuracy: row['accuracy'],
            provider: row['provider'],
            elapsed_time: row['elapsed_time']
        );
        wtp.setId(row['id']);
        walk.track.add(wtp);
      }

      results = await db.rawQuery(getWalkImages, [walkName]);
      for (var row in results) {
        walk.images.add( new WalkImage(
          image_name: row['image_name'],
          create_date: row['create_date'],
          latitude: row['latitude'],
          longitude: row['longitude'],
          distance: row['distance'],
        ));
      }

      results = await db.rawQuery(getWalkWaypoints, [walkName]);
      for (var row in results) {
        WalkWaypoint ww = new WalkWaypoint(
          latitude: row['latitude'],
          longitude: row['longitude'],
        );
        ww.setId(row['id']);
        walk.waypoints.add(ww);
      }
    } catch (err) {
      throw Exception("Walk $walkName cannot be retrieved");
    }
    return(walk);
  }

  // Retrieve a walk's distance
  //      getWalkDistance
  Future<double> getWalkDistance(String walkName) async {
    Database db = await database;
    var num_walks = 0;
    try {
      var results = await db.rawQuery(getWalkId, [walkName]);
      num_walks = results.length;
    } catch (err) {
      throw Exception("Optimum duration cannot be retrieved for walk $walkName");
    }
    if (num_walks != 1) {
      throw Exception("Walk $walkName does not exist");
    }

    double distance = 0;
    try {
      var results = await db.rawQuery(getDistance, [walkName]);
      if (results.length > 0 && results[0]["distance"] != null) {
        distance = results[0]["distance"] as double;
      }
    } catch (err) {
      throw Exception("Cannot retrieve distance for walk $walkName");
    }
    return(distance);
  }

  // Retrieve a walk's optimum duration
  //      getWalkOptimumDuration
  Future<int> getWalkOptimumDurationInSeconds(String walkName) async {
    Database db = await database;
    var num_walks = 0;
    try {
      var results = await db.rawQuery(getWalkId, [walkName]);
      num_walks = results.length;
    } catch (err) {
      throw Exception("Optimum duration cannot be retrieved for walk $walkName");
    }
    if (num_walks != 1) {
      throw Exception("Walk $walkName does not exist");
    }

    int optimumDuration = 0;
    try {
      var results = await db.rawQuery(getWalkDetails, [walkName]);
      if (results[0]["optimum_minutes"] != null && results[0]["optimum_seconds"] != null) {
        int minutes = results[0]["optimum_minutes"] as int;
        int seconds = results[0]["optimum_seconds"] as int;
        optimumDuration = minutes*60 + seconds;
      }
    } catch (err) {
      throw Exception("Cannot retrieve optimum duration for walk $walkName");
    }
    return(optimumDuration);
  }

  // Update a walk optimum duration
  //      updateWalkOptimumDuration
  Future<void> updateWalkOptimumDurn(String walkName, int minutes, int seconds) async {
    Database db = await database;
    var num_walks = 0;
    try {
      var results = await db.rawQuery(getWalkId, [walkName]);
      num_walks = results.length;
    } catch (err) {
      throw Exception("Points cannot be added to walk $walkName");
    }
    if (num_walks != 1) {
      throw Exception("Walk $walkName does not exist");
    }

    await db.execute(updateWalkOptimumDuration,[minutes, seconds, walkName]);
  }

  // Add walk track point(s)
  Future<void> addWalkTrackPoints(String walkName, List<WalkTrackPoint> points) async {
    Database db = await database;
    int num_walks = 0;

    try {
      var results = await db.rawQuery(getWalkId, [walkName]);
      num_walks = results.length;
    } catch (err) {
      throw Exception("Points cannot be added to walk $walkName");
    }
    if (num_walks != 1) {
      throw Exception("Walk $walkName does not exist");
    }

    try {
      for (var point in points) {
        await db.execute(insertWalkTrackPoint,[
          point.create_date,
          point.latitude,
          point.longitude,
          point.distance,
          point.accuracy,
          point.provider,
          point.elapsed_time,
          walkName,
        ]);
      }
    } catch (err) {
      throw Exception("Points cannot be added to walk $walkName");
    }
  }

  // Add walk image(s)
  Future<void> addWalkImages(String walkName, List<WalkImage> images) async {
    Database db = await database;
    int num_walks = 0;

    try {
      var results = await db.rawQuery(getWalkId, [walkName]);
      num_walks = results.length;
    } catch (err) {
      throw Exception("Images cannot be added to walk $walkName");
    }
    if (num_walks != 1) {
      throw Exception("Walk $walkName does not exist");
    }

    try {
      for (var image in images) {
        await db.execute(insertWalkImage,[
          image.image_name,
          image.create_date,
          image.latitude,
          image.longitude,
          image.distance,
          walkName,
        ]);
      }
    } catch (err) {
      throw Exception("Images cannot be added to walk $walkName");
    }
  }

  // Add walk waypoint(s)
  Future<void> addWalkWaypoints(String walkName, List<WalkWaypoint> waypoints) async {
    Database db = await database;
    int num_walks = 0;

    try {
      var results = await db.rawQuery(getWalkId, [walkName]);
      num_walks = results.length;
    } catch (err) {
      throw Exception("Waypoints cannot be added to walk $walkName");
    }
    if (num_walks != 1) {
      throw Exception("Walk $walkName does not exist");
    }

    try {
      for (var waypoint in waypoints) {
        await db.execute(insertWalkWaypoint,[
          waypoint.latitude,
          waypoint.longitude,
          walkName,
        ]);
      }
    } catch (err) {
      throw Exception("Waypoints cannot be added to walk $walkName");
    }
  }

  // Delete walk waypoint(s)
  Future<void> deleteWaypointsFromWalk (name) async {
    Database db = await database;
    List results = await db.rawQuery(getWalkId, [name]);
    if (results.isEmpty) {
      throw Exception("Walk $name does not exist");
    }
    int id = results[0]["id"];
    await db.execute(deleteWalkWaypoints,[id]);
  }
}

class Walk {
  late int id;
  final String name;
  final String create_date;
  late int status;
  final int optimum_minutes;
  final int optimum_seconds;
  List<WalkTrackPoint> track = [];
  List<WalkImage> images = [];
  List<WalkWaypoint> waypoints = [];

  Walk({
    required this.name,
    required this.create_date,
    required this.optimum_minutes,
    required this.optimum_seconds,
  });

  String toJson() {
    String json = '{"name": "$name", "created": "$create_date", "optimum_mins": $optimum_minutes, "optimum_secs": $optimum_seconds';

    if (track.isNotEmpty) {
      bool first = true;
      for (var point in track) {
        if (first) {
          first = false;
          json += ',"track" : [' + point.toJson();
        } else {
          json += ", " + point.toJson();
        }
      }
      json += ']';
    }

    if (waypoints.isNotEmpty) {
      json += ', ';
      bool first = true;
      for (var waypoint in waypoints) {
        if (first) {
          first = false;
          json += '"waypoints" : [' + waypoint.toJson();
        } else {
          json += ',' + waypoint.toJson();
        }
      }
      json += ']';
    }

    json += '}';
    return(json);
  }

  @override
  String toString() {
    String s = "name $name created $create_date optimum_mins $optimum_minutes optimum_secs $optimum_seconds\n";
    s += "track\n";
    for (var point in track) {
      s += point.toString();
    }
    s += "images\n";
    for (var image in images) {
      s += image.toString() + "\n";
    }
    s += "waypoints\n";
    for (var waypoint in waypoints) {
      s += waypoint.toString() + "\n";
    }
    return(s);
  }
}

class WalkTrackPoint {
  late int id;
  late int walk_id;
  final String create_date;
  final double latitude;
  final double longitude;
  final double distance;
  final String provider;
  final double accuracy;
  final int elapsed_time;

  WalkTrackPoint({
    required this.create_date,
    required this.latitude,
    required this.longitude,
    required this.distance,
    required this.provider,
    required this.accuracy,
    required this.elapsed_time
  });

  void setId(var id) {
    this.id = id;
  }

  String toJson() {
    return('{ "sequence": $id, "created": "$create_date", "latitude": $latitude, "longitude": $longitude, "distance": $distance, "provider": "$provider", "accuracy": $accuracy, "elapsed_time": $elapsed_time}');
  }

  @override
  String toString() {
    return(" created $create_date latitude $latitude longitude $longitude distance $distance provider $provider accuracy $accuracy elapsed_time $elapsed_time");
  }
}

class WalkImage {
  late int id;
  late int walk_id;
  final String image_name;
  final String create_date;
  final double latitude;
  final double longitude;
  final double distance;

  WalkImage({
    required this.image_name,
    required this.create_date,
    required this.latitude,
    required this.longitude,
    required this.distance,
  });

  @override
  String toString() {
    return(" name $image_name created $create_date latitude $latitude longitude $longitude distance $distance");
  }
}

class WalkWaypoint {
  late int id;
  late int walk_id;
  final double latitude;
  final double longitude;

  WalkWaypoint({
    required this.latitude,
    required this.longitude,
  });

  void setId(var id) {
    this.id = id;
  }

  String toJson() {
    return('{"sequence": $id, "latitude": $latitude, "longitude": $longitude}');
  }
  @override
  String toString() {
    return(" latitude $latitude longitude $longitude");
  }
}

