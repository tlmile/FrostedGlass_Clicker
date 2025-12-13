import 'dart:ui';
import 'package:flutter/material.dart';

const String kFloatingBallThemeKey = 'floating_ball_theme_id';

/// 定位喵球主题配置
class BallTheme {
  final String id; // 用来保存到本地 & 传给原生
  final String name; // 显示的名称
  final List<Color> colors; // 渐变颜色 [中心色, 外圈色]
  final Color textColor; // 数字颜色

  const BallTheme({
    required this.id,
    required this.name,
    required this.colors,
    required this.textColor,
  });
}

const List<BallTheme> kBallThemes = [
  BallTheme(
    id: 'tech_blue',
    name: '科技蓝',
    colors: [
      Color(0xFF4DA8FF), // 中心亮蓝
      Color(0xFF0052CC), // 外圈深蓝
    ],
    textColor: Colors.white,
  ),
  BallTheme(
    id: 'morandi_green',
    name: '莫兰迪绿',
    colors: [
      Color(0xFFD8E6D3),
      Color(0xFF6C8A73),
    ],
    textColor: Color(0xFF2B2A2A),
  ),
  BallTheme(
    id: 'coral',
    name: '珊瑚粉',
    colors: [
      Color(0xFFFFD6D6),
      Color(0xFFFF6F6F),
    ],
    textColor: Colors.white,
  ),
  BallTheme(
    id: 'bright_yellow',
    name: '亮黄',
    colors: [
      Color(0xFFFFF7B2),
      Color(0xFFFFD600),
    ],
    textColor: Color(0xFF2B2A2A),
  ),
  BallTheme(
    id: 'dark_gray',
    name: '暗夜灰',
    colors: [
      Color(0xFF4A4A4A),
      Color(0xFF1E1E1E),
    ],
    textColor: Colors.white,
  ),
  BallTheme(
    id: 'neon_purple',
    name: '霓虹紫',
    colors: [
      Color(0xFFE0C3FC),
      Color(0xFF8E2DE2),
    ],
    textColor: Colors.white,
  ),
  BallTheme(
    id: 'cyan',
    name: '青色',
    colors: [
      Color(0xFFB2FEFA),
      Color(0xFF0ED2F7),
    ],
    textColor: Color(0xFF034057),
  ),
  BallTheme(
    id: 'soft_orange',
    name: '柔和橙',
    colors: [
      Color(0xFFFFE0B2),
      Color(0xFFFF9800),
    ],
    textColor: Color(0xFF4A2C00),
  ),
];

/// 渐变球组件（大数字 + 字体阴影）
class GradientBall extends StatelessWidget {
  final BallTheme theme;
  final double size;
  final String text;
  final double defaultSize;
  final double defaultTextSize;

  const GradientBall({
    super.key,
    required this.theme,
    this.size = 60,
    this.text = '3',
    this.defaultSize = 45,
    this.defaultTextSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    final double fontSize = size >= defaultSize
        ? defaultTextSize
        : defaultTextSize * (size / defaultSize);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: theme.colors,
          center: Alignment.center,
          radius: 0.9,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: theme.textColor,
          shadows: const [
            Shadow(
              offset: Offset(1, 1),
              blurRadius: 3,
              color: Colors.black38,
            ),
            Shadow(
              offset: Offset(-1, -1),
              blurRadius: 3,
              color: Colors.black12,
            ),
          ],
        ),
      ),
    );
  }
}
