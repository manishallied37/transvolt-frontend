import 'package:flutter/material.dart';

class DashboardWidgetModel {

  final String id;
  final Widget widget;

  int width;   // grid width (1 or 2)
  int height;  // grid height (1 or 2)

  DashboardWidgetModel({
    required this.id,
    required this.widget,
    this.width = 1,
    this.height = 1,
  });
}