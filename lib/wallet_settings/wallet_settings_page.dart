import 'dart:async';

import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sync.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/popup_border.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bb_mobile/wallet_settings/addresses.dart';
import 'package:bb_mobile/wallet_settings/backup.dart';
import 'package:bb_mobile/wallet_settings/bloc/state.dart';
import 'package:bb_mobile/wallet_settings/bloc/wallet_settings_cubit.dart';
import 'package:bb_mobile/wallet_settings/descriptors.dart';
import 'package:extra_alignments/extra_alignments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class WalletSettingsPage extends StatelessWidget {
  const WalletSettingsPage({super.key, this.openTestBackup = false});

  final bool openTestBackup;

  @override
  Widget build(BuildContext context) {
    final home = locator<HomeCubit>();
    final wallet = home.state.selectedWalletCubit!;
    final walletSettings = WalletSettingsCubit(
      wallet: wallet.state.wallet!,
      walletRead: locator<WalletSync>(),
      hiveStorage: locator<HiveStorage>(),
      secureStorage: locator<SecureStorage>(),
      walletBloc: wallet,
      fileStorage: locator<FileStorage>(),
      walletRepository: locator<WalletRepository>(),
      walletSensRepository: locator<WalletSensitiveRepository>(),
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: wallet),
        BlocProvider.value(value: walletSettings),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<WalletSettingsCubit, WalletSettingsState>(
            listenWhen: (previous, current) => previous.wallet != current.wallet,
            listener: (context, state) {
              if (!state.deleted)
                home.updateSelectedWallet(wallet);
              else {
                context.pop();
                home.getWalletsFromStorage();
              }
            },
          ),
          BlocListener<WalletSettingsCubit, WalletSettingsState>(
            listenWhen: (previous, current) => previous.savedName != current.savedName,
            listener: (context, state) {
              if (state.savedName) FocusScope.of(context).requestFocus(FocusNode());
            },
          ),
        ],
        child: _Screen(openTestBackup: openTestBackup),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen({required this.openTestBackup});

  final bool openTestBackup;

  @override
  Widget build(BuildContext context) {
    if (openTestBackup)
      scheduleMicrotask(() async {
        await Future.delayed(const Duration(milliseconds: 1000));
        await TestBackupScreen.openPopup(context);
      });

    final watchOnly = context.select((WalletSettingsCubit cubit) => cubit.state.wallet.watchOnly());
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: const ApppBar(),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Gap(16),
              const WalletName(),
              const Gap(16),
              const WalletType(),
              const Gap(16),
              const Balances(),
              const Gap(24),
              if (!watchOnly) ...[
                const BackupButton(),
                const Gap(8),
                const TestBackupButton(),
                const Gap(8),
              ],
              const PublicDescriptorButton(),
              const Gap(8),
              const ExtendedPublicKeyButton(),
              const Gap(8),
              const AddressesButtons(),
              const Gap(8),
              const AccountingButton(),
              const Gap(8),
              const DeleteButton(),
              const Gap(24),
            ],
          ),
        ),
      ),
    );
  }
}

class ApppBar extends StatelessWidget {
  const ApppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final walletName = context.select(
      (WalletSettingsCubit cubit) => cubit.state.wallet.name,
    );

    final fingerPrint = context.select(
      (WalletSettingsCubit cubit) => cubit.state.wallet.sourceFingerprint,
    );

    return BBAppBar(
      onBack: () {
        context.pop();
      },
      text: walletName ?? fingerPrint,
    );
  }
}

class WalletName extends StatefulWidget {
  const WalletName({super.key});

  @override
  State<WalletName> createState() => _WalletNameState();
}

class _WalletNameState extends State<WalletName> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final saving = context.select(
      (WalletSettingsCubit x) => x.state.savingName,
    );

    final text = context.select(
      (WalletSettingsCubit x) => x.state.name,
    );
    if (text != _controller.text) _controller.text = text;

    final name = context.select(
      (WalletSettingsCubit x) => x.state.wallet.name,
    );

    final showSave = text.isNotEmpty && name != text;

    return Row(
      children: [
        Expanded(
          child: BBTextInput.small(
            onChanged: (txt) {
              context.read<WalletSettingsCubit>().changeName(txt);
            },
            value: text,
            hint: name ?? 'Enter name',
          ),
        ),
        const Gap(16),
        if (!saving)
          BBButton.smallRed(
            disabled: !showSave,
            label: 'SAVE',
            onPressed: () {
              context.read<WalletSettingsCubit>().saveNameClicked();
            },
          )
        else
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }
}

class WalletType extends StatelessWidget {
  const WalletType({super.key});

  @override
  Widget build(BuildContext context) {
    final type = context.select((WalletSettingsCubit x) => x.state.wallet.getWalletTypeString());
    final scriptType = context.select((WalletSettingsCubit x) => x.state.wallet.scriptType);
    final _ = scriptTypeString(scriptType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.title('Type'),
        const Gap(4),
        BBText.titleLarge(
          type,
          isBold: true,
        ),
      ],
    );
  }
}

class Balances extends StatelessWidget {
  const Balances({super.key});

  @override
  Widget build(BuildContext context) {
    final amtSent = context.select(
      (WalletBloc cubit) => cubit.state.wallet!.totalSent(),
    );

    final amtReceived = context.select(
      (WalletBloc cubit) => cubit.state.wallet!.totalReceived(),
    );

    final inAmt = context.select(
      (SettingsCubit x) => x.state.getAmountInUnits(amtReceived, removeText: true),
    );

    final outAmt = context.select(
      (SettingsCubit x) => x.state.getAmountInUnits(amtSent, removeText: true),
    );

    final units = context.select((SettingsCubit x) => x.state.getUnitString());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.title('Total amount received'),
        const Gap(4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              transformAlignment: Alignment.center,
              transform: Matrix4.identity()
                ..rotateZ(
                  1,
                ),
              child: const FaIcon(
                FontAwesomeIcons.arrowRight,
              ),
            ),
            const Gap(16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText.titleLarge(
                  inAmt,
                  isBold: true,
                ),
              ],
            ),
            const Gap(4),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: BBText.title(
                units,
                isBold: true,
              ),
            ),
          ],
        ),
        const Gap(16),
        const BBText.title('Total amount sent'),
        const Gap(4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              transformAlignment: Alignment.center,
              transform: Matrix4.identity()
                ..rotateZ(
                  -1,
                ),
              child: const FaIcon(
                FontAwesomeIcons.arrowRight,
              ),
            ),
            const Gap(16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText.titleLarge(
                  outAmt,
                  isBold: true,
                ),
              ],
            ),
            const Gap(4),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: BBText.title(
                units,
                isBold: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class AddressesButtons extends StatelessWidget {
  const AddressesButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.textWithStatusAndRightArrow(
      label: 'Addresses',
      onPressed: () {
        AddressesScreen.openPopup(context);
      },
    );
  }
}

class AccountingButton extends StatelessWidget {
  const AccountingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.textWithStatusAndRightArrow(
      label: 'Accounting',
      onPressed: () {
        final walletBloc = context.read<WalletBloc>();
        context.push('/wallet-settings/accounting', extra: walletBloc);
      },
    );
  }
}

class TestBackupButton extends StatelessWidget {
  const TestBackupButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isTested = context.select((WalletBloc x) => x.state.wallet!.backupTested);

    // if (isTested) return const SizedBox.shrink();
    return BBButton.textWithStatusAndRightArrow(
      label: 'Test Backup',
      statusText: isTested ? 'Tested' : 'Not Tested',
      isRed: !isTested,
      onPressed: () async {
        await TestBackupScreen.openPopup(context);
      },
    );
    // return Row(
    //   children: [
    //     BBButton.textWithLeftArrow(
    //       label: 'Test Backup',
    //       onPressed: () async {
    //         await TestBackupScreen.openPopup(context);
    //       },
    //     ),
    //     const Spacer(),
    //     BBText.body(
    //       isTested ? 'Tested' : 'Not tested',
    //       isGreen: isTested,
    //       isRed: !isTested,
    //     ),
    //   ],
    // );
  }
}

class BackupButton extends StatelessWidget {
  const BackupButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.textWithStatusAndRightArrow(
      onPressed: () async {
        await BackupScreen.openPopup(context);
      },
      label: 'Backup',
    );
  }
}

class DeleteButton extends StatelessWidget {
  const DeleteButton({super.key});

  @override
  Widget build(BuildContext context) {
    return CenterLeft(
      child: BBButton.text(
        isRed: true,
        onPressed: () {
          DeletePopUp.openPopUp(context);
        },
        label: 'Delete Wallet',
      ),
    );
  }
}

class DeletePopUp extends StatelessWidget {
  const DeletePopUp({super.key});

  static Future openPopUp(BuildContext context) {
    final settings = context.read<WalletSettingsCubit>();

    return showMaterialModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: settings),
        ],
        child: BlocListener<WalletSettingsCubit, WalletSettingsState>(
          listenWhen: (previous, current) => previous.deleted != current.deleted,
          listener: (context, state) {
            if (state.deleted) {
              final home = locator<HomeCubit>();
              context.go('/home');
              home.clearSelectedWallet(removeWallet: true);
            }
          },
          child: const PopUpBorder(
            child: DeletePopUp(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Gap(32),
        const BBText.body(
          'Delete wallet',
        ),
        const Gap(24),
        const BBText.body(
          'Are you sure you want to delete this wallet?',
          textAlign: TextAlign.center,
        ),
        const Gap(40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: BBButton.text(
                  onPressed: () {
                    context.pop();
                  },
                  label: 'Cancel',
                ),
              ),
              Expanded(
                child: BBButton.smallRed(
                  filled: true,
                  onPressed: () {
                    context.read<WalletSettingsCubit>().deleteWalletClicked();
                  },
                  label: 'Delete',
                ),
              ),
            ],
          ),
        ),
        const Gap(40),
      ],
    );
  }
}
