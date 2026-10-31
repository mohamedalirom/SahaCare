import 'package:flutter/material.dart';

import '../../data/services/medication_notification_service.dart';

/// Keeps medication screens clear of the simulated notch and floating tab bar.
class MedicationScaffold extends StatefulWidget {
  const MedicationScaffold({
    super.key,
    required this.backgroundColor,
    required this.appBar,
    required this.body,
    this.reserveNavigationSpace = false,
    this.bottomAction,
    this.manageNotifications = true,
  });

  final Color backgroundColor;
  final PreferredSizeWidget appBar;
  final Widget body;
  final bool reserveNavigationSpace;
  final Widget? bottomAction;
  final bool manageNotifications;

  @override
  State<MedicationScaffold> createState() => _MedicationScaffoldState();
}

class _MedicationScaffoldState extends State<MedicationScaffold> {
  @override
  void initState() {
    super.initState();
    if (widget.manageNotifications) {
      MedicationNotificationService.instance.start();
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // PhoneFrameWrapper constrains the content, but retains the desktop
      // MediaQuery. Its notch ends 38 logical pixels below the frame's top.
      final simulatedPhone =
          MediaQuery.sizeOf(context).width >= 550 && constraints.maxWidth < 550;
      final bottomInset = MediaQuery.paddingOf(context).bottom;
      return ColoredBox(
        color: Colors.white,
        child: SafeArea(
          minimum: EdgeInsets.only(
            top: simulatedPhone ? 48 : 0,
            // The tab bar is 60 high, positioned 24 above the safe bottom.
            bottom: widget.reserveNavigationSpace
                ? 100 + bottomInset
                : simulatedPhone
                ? 16
                : 0,
          ),
          child: Scaffold(
            backgroundColor: widget.backgroundColor,
            appBar: widget.appBar,
            body: widget.manageNotifications
                ? ValueListenableBuilder<MedicationNotificationState>(
                    valueListenable: MedicationNotificationService.instance,
                    builder: (context, state, _) => Column(
                      children: [
                        if (state.status == MedicationNotificationStatus.error)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              state.message,
                              style: const TextStyle(color: Color(0xFFB91C1C)),
                            ),
                          ),
                        Expanded(child: widget.body),
                      ],
                    ),
                  )
                : widget.body,
            bottomNavigationBar: widget.bottomAction,
          ),
        ),
      );
    },
  );
}
