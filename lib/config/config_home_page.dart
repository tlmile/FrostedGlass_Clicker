import 'package:flutter/material.dart';
import 'floating_ball_config_page.dart';

class ConfigHomePage extends StatelessWidget {
  const ConfigHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('配置中心'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            Text(
              '基础配置',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // 悬浮球配置卡片
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FloatingBallConfigPage(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary.withOpacity(0.12),
                        ),
                        child: Icon(
                          Icons.circle_outlined,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '定位喵球配置',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '主题颜色与样式设置',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color
                                    ?.withOpacity(0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // 预留未来可扩展配置项
            Text(
              '高级配置（预留）',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: colorScheme.surfaceVariant.withOpacity(0.3),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 20,
                    color: colorScheme.secondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '这里可以在后续加入「自动点击策略」等更细粒度的配置项。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color
                            ?.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
