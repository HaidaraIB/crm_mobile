import 'package:flutter/material.dart';

/// For screens that refresh when the user comes back to them ([RouteAware.didPopNext]).
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
