import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/security/safe_clipboard.dart';
import '../../../core/utils/json_utils.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../provider/jwt_provider.dart';

/// Page for decoding JSON Web Tokens locally.
class JwtPage extends ConsumerStatefulWidget {
  const JwtPage({super.key});

  @override
  ConsumerState<JwtPage> createState() => _JwtPageState();
}

class _JwtPageState extends ConsumerState<JwtPage> {
  late final TextEditingController _inputController;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(text: ref.read(jwtInputProvider));
    _inputController.addListener(() {
      ref.read(jwtInputProvider.notifier).state = _inputController.text;
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decoded = ref.watch(jwtDecodedProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('JWT Decoder')),
      body: Padding(
        padding: AppSpacing.page(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Token input',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: _inputController,
                    maxLines: 4,
                    style: AppTypography.mono(context),
                    decoration: InputDecoration(
                      hintText: 'eyJhbGciOiJIUzI1NiIsInR...',
                      fillColor: AppColors.codeBackground(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: () => decodeJwt(ref),
                      icon: const Icon(Icons.travel_explore),
                      label: const Text('Decode'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: decoded.when(
                data: (result) {
                  if (result.isEmpty) {
                    return const AppEmptyState(
                      icon: Icons.lock_open,
                      title: 'Enter a token to decode',
                      message:
                          'Header, payload, claims and expiry details stay local on this device.',
                    );
                  }
                  return _DecodedJwtView(result: result);
                },
                loading: () =>
                    const AppLoadingState(label: 'Decoding token...'),
                error: (err, stack) => AppErrorState(message: err.toString()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecodedJwtView extends StatelessWidget {
  final Map<String, dynamic> result;

  const _DecodedJwtView({required this.result});

  @override
  Widget build(BuildContext context) {
    final header = JsonUtils.prettyPrint(result['header']);
    final payload = JsonUtils.prettyPrint(result['payload']);
    final payloadMap = result['payload'] as Map<String, dynamic>;
    final expiry = result['expiry'] as DateTime?;
    final issuedAt = result['issuedAt'] as DateTime?;
    final notBefore = result['notBefore'] as DateTime?;
    final expired = result['isExpired'] == true;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Signature not verified'),
                    SizedBox(height: 2),
                    Text(
                      'This tool decodes the token header and payload locally. It does not validate the signing key.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Claims timeline',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (expiry != null)
                    AppBadge(
                      label: expired ? 'Expired' : 'Active',
                      icon: expired ? Icons.error_outline : Icons.check,
                      color:
                          expired ? AppColors.destructive : AppColors.success,
                      backgroundColor: expired
                          ? Theme.of(context).colorScheme.errorContainer
                          : AppColors.successContainer(context),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (expiry == null && issuedAt == null && notBefore == null)
                Text(
                  'No standard time claims were found.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              if (expiry != null)
                _TimeClaimTile(
                  label: 'Expires',
                  value: expiry,
                  isWarning: expired,
                  warningText: expired ? 'Expired' : null,
                ),
              if (issuedAt != null)
                _TimeClaimTile(label: 'Issued at', value: issuedAt),
              if (notBefore != null)
                _TimeClaimTile(label: 'Not before', value: notBefore),
              if (payloadMap['name'] != null)
                _ClaimValue(
                    label: 'Name', value: payloadMap['name'].toString()),
              if (payloadMap['sub'] != null)
                _ClaimValue(
                  label: 'Subject',
                  value: payloadMap['sub'].toString(),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _JsonPanel(title: 'Header', text: header),
        const SizedBox(height: AppSpacing.md),
        _JsonPanel(title: 'Payload', text: payload),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () async {
              final jsonString = JsonUtils.prettyPrint(_copyableResult(result));
              await SafeClipboard.copy(
                jsonString,
                content: SafeClipboardContent.json,
                forceRedaction: true,
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied JSON with sensitive claims redacted'),
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy JSON'),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _copyableResult(Map<String, dynamic> source) {
    String? encodeDate(String key) {
      final value = source[key];
      return value is DateTime ? value.toIso8601String() : null;
    }

    return {
      'header': source['header'],
      'payload': source['payload'],
      'expiry': encodeDate('expiry'),
      'issuedAt': encodeDate('issuedAt'),
      'notBefore': encodeDate('notBefore'),
      'isExpired': source['isExpired'],
      'signatureVerified': false,
    };
  }
}

class _ClaimValue extends StatelessWidget {
  final String label;
  final String value;

  const _ClaimValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          SelectableText(value),
        ],
      ),
    );
  }
}

class _JsonPanel extends StatelessWidget {
  final String title;
  final String text;

  const _JsonPanel({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy $title',
                  onPressed: () async {
                    await SafeClipboard.copy(
                      text,
                      content: SafeClipboardContent.json,
                      forceRedaction: true,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              '$title copied with sensitive claims redacted')),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            color: AppColors.codeBackground(context),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(text, style: AppTypography.mono(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeClaimTile extends StatelessWidget {
  final String label;
  final DateTime value;
  final bool isWarning;
  final String? warningText;

  const _TimeClaimTile({
    required this.label,
    required this.value,
    this.isWarning = false,
    this.warningText,
  });

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? Theme.of(context).colorScheme.error : null;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                SelectableText(
                  'Local: ${value.toLocal()}\nUTC: ${value.toUtc()}',
                ),
              ],
            ),
          ),
          if (warningText != null)
            Text(warningText!, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
