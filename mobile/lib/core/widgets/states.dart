import 'package:flutter/material.dart';

import 'widgets.dart';

/// Shared progress indicator for buttons and content states.
class KLoading extends StatelessWidget {
  const KLoading({super.key, this.size = 22, this.color = AppColors.primary});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Sedang memuat',
    liveRegion: true,
    child: SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(strokeWidth: 3, color: color),
    ),
  );
}

/// Root-overlay loading state that covers the page and bottom navigation.
class KLoadingOverlay extends StatefulWidget {
  const KLoadingOverlay({
    super.key,
    required this.loading,
    required this.child,
    this.message = 'Sebentar, ya…',
  });

  final bool loading;
  final Widget child;
  final String message;

  @override
  State<KLoadingOverlay> createState() => _KLoadingOverlayState();
}

class _KLoadingOverlayState extends State<KLoadingOverlay> {
  final _portal = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    _syncOverlay();
  }

  @override
  void didUpdateWidget(KLoadingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loading != widget.loading) _syncOverlay();
  }

  void _syncOverlay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.loading ? _portal.show() : _portal.hide();
    });
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    overlayLocation: OverlayChildLocation.rootOverlay,
    controller: _portal,
    overlayChildBuilder: (context) => widget.loading
        ? Positioned.fill(
            child: BlockSemantics(
              child: Stack(
                children: [
                  const ModalBarrier(
                    dismissible: false,
                    color: Color(0x6B000000),
                  ),
                  Center(
                    child: Semantics(
                      liveRegion: true,
                      label: widget.message,
                      child: Material(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 208,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ExcludeSemantics(
                                child: MascotBody(
                                  animal: Animal.ciko,
                                  stage: Stage.gesit,
                                  size: 104,
                                  float: false,
                                  animated: !MediaQuery.disableAnimationsOf(
                                    context,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.message,
                                textAlign: TextAlign.center,
                                style: AppText.name(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        : const SizedBox.shrink(),
    child: PopScope(
      canPop: !widget.loading,
      child: ExcludeSemantics(excluding: widget.loading, child: widget.child),
    ),
  );
}

/// Illustrated loading, empty, and recoverable error states for list content.
class KContentState extends StatelessWidget {
  const KContentState({
    super.key,
    required this.title,
    required this.message,
    this.loading = false,
    this.error = false,
    this.compact = false,
    this.action,
    this.onAction,
  });

  final String title;
  final String message;
  final bool loading;
  final bool error;
  final bool compact;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return KLoadingOverlay(
        loading: true,
        message: title,
        child: const SizedBox(height: 240),
      );
    }
    if (compact) {
      return Row(
        children: [
          const MascotHead(
            animal: Animal.ciko,
            size: 64,
            float: false,
            bg: AppColors.primaryL,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.name()),
                const SizedBox(height: 4),
                Text(message, style: AppText.bodySm()),
              ],
            ),
          ),
        ],
      );
    }
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MascotHead(
              float: false,
              animal: error ? Animal.kiki : Animal.ciko,
              stage: Stage.gesit,
              size: 112,
              bg: error ? AppColors.orangeL : AppColors.primaryL,
            ),
            const SizedBox(height: 20),
            Text(title, style: AppText.title(), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: AppText.bodySm(), textAlign: TextAlign.center),
            if (action != null && onAction != null) ...[
              const SizedBox(height: 20),
              KButton.secondary(action!, onTap: onAction, expand: false),
            ],
          ],
        ),
      ),
    );
  }
}
