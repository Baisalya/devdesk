import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/json_utils.dart';
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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Paste JWT Token'),
            const SizedBox(height: 4),
            TextField(
              controller: _inputController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'eyJhbGciOiJIUzI1NiIsInR...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => decodeJwt(ref),
              child: const Text('Decode'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: decoded.when(
                data: (result) {
                  if (result.isEmpty) {
                    return const Text('Enter a token to decode.');
                  }
                  return _DecodedJwtView(result: result);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Text(
                  err.toString(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
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
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.warning_amber),
            title: const Text('Signature not verified'),
            subtitle: const Text(
              'This tool only decodes the token header and payload locally.',
            ),
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
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Name'),
            subtitle: Text(payloadMap['name'].toString()),
          ),
        if (payloadMap['sub'] != null)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Subject'),
            subtitle: Text(payloadMap['sub'].toString()),
          ),
        const SizedBox(height: 8),
        const Text('Header'),
        _JsonBox(text: header),
        const SizedBox(height: 8),
        const Text('Payload'),
        _JsonBox(text: payload),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () async {
            final jsonString = JsonUtils.prettyPrint(_copyableResult(result));
            await Clipboard.setData(ClipboardData(text: jsonString));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied JSON to clipboard')),
            );
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copy JSON'),
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
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text('Local: ${value.toLocal()}\nUTC: ${value.toUtc()}'),
      trailing: warningText == null
          ? null
          : Text(warningText!, style: TextStyle(color: color)),
    );
  }
}

class _JsonBox extends StatelessWidget {
  final String text;

  const _JsonBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SelectableText(text),
      ),
    );
  }
}
