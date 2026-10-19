import 'package:flutter/material.dart';

class NoteDesign {
  const NoteDesign(this.title, this.icon, this.color);
  final String title;
  final String icon;
  final Color color;
  String get kind => icon == '✿'
      ? 'bloom'
      : icon == '✦'
          ? 'star'
          : 'letter';
  Color get accent => kind == 'bloom'
      ? const Color(0xff99536f)
      : kind == 'star'
          ? const Color(0xff756396)
          : const Color(0xff99674d);
  IconData get symbol => kind == 'bloom'
      ? Icons.local_florist_outlined
      : kind == 'star'
          ? Icons.auto_awesome_outlined
          : Icons.mail_outline;
}

const noteDesign = <String, NoteDesign>{
  'letter': NoteDesign('Letter', '✉', Color(0xfffff8ed)),
  'bloom': NoteDesign('Flowers', '✿', Color(0xfffaf0f3)),
  'star': NoteDesign('Stars', '✦', Color(0xfff3f0fa)),
};
