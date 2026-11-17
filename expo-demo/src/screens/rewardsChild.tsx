import React, { useCallback, useEffect, useState } from 'react';
import { RefreshControl, ScrollView, Text, View } from 'react-native';

import {
  CenterSpinner,
  ErrorNote,
  Icon,
  RowLabel,
  StickerCard,
  StickerEmoji,
  StickerPage,
  StickerPill,
  StoryButton,
  type IconName,
} from '../components/sticker';
import { useNav } from '../nav/Navigator';
import { CoinError, CoinService, costOf, type CoinTransaction } from '../services/coins';
import { useLiveRefresh } from '../services/firestoreChanges';
import { RewardStore, type Reward } from '../services/rewards';
import { usePalette } from '../theme/ThemeProvider';
import { body, display, outlineWidth, outlineWidthThin, radiusButton, radiusTile, tintForIndex } from '../theme/palette';

/**
 * What a child can work toward (CR #2): their coin balance, the rewards their
 * parent has set up, and the requests they have already made.
 */
export function ChildRewardsScreen({ childId, childName }: { childId: string; childName: string }) {
  const palette = usePalette();
  const nav = useNav();
  const [rewards, setRewards] = useState<Reward[] | null>(null);
  const [balance, setBalance] = useState(0);
  const [requests, setRequests] = useState<CoinTransaction[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [redeeming, setRedeeming] = useState(false);
  const [refreshing, setRefreshing] = useState(false);

  const load = useCallback(async () => {
    let list: Reward[] = [];
    try {
      list = await RewardStore.load(true);
    } catch {
      list = [];
    }
    let coins = 0;
    let mine: CoinTransaction[] = [];
    try {
      coins = await CoinService.balance(childId);
      mine = await CoinService.redemptions(childId);
    } catch {
      // Shown as empty.
    }
    setRewards(list);
    setBalance(coins);
    setRequests(mine);
  }, [childId]);

  useEffect(() => {
    load();
  }, [load]);
  // The parent can add rewards, or give or decline requests, meanwhile.
  useLiveRefresh(() => [RewardStore.changes(), CoinService.changes(childId)], load);

  const redeem = async (reward: Reward) => {
    const confirmed = await nav.showDialog<boolean>(
      <KidDialog
        emoji="🎁"
        title={`Get "${reward.title}"?`}
        message={`This spends ${reward.coinCost} of your ${balance} coins.`}
        primary="Yes, redeem!"
        onPrimary={() => nav.pop(true)}
        secondary="Not yet"
        onSecondary={() => nav.pop(false)}
      />,
    );
    if (!confirmed) return;
    setError(null);
    setRedeeming(true);
    try {
      await CoinService.redeem(childId, reward.id);
    } catch (e) {
      setError(e instanceof CoinError ? e.message : 'Something went wrong. Try again in a moment.');
      await load();
      setRedeeming(false);
      return;
    }
    await load();
    setRedeeming(false);
    await nav.showDialog(
      <KidDialog
        emoji="🎉"
        title="You did it!"
        message={`You redeemed "${reward.title}". Your grown-up has been told!`}
        primary="Yay!"
        onPrimary={() => nav.pop()}
      />,
    );
  };

  return (
    <StickerPage title="My Rewards">
      {rewards == null ? (
        <CenterSpinner />
      ) : (
        <ScrollView
          contentContainerStyle={{ padding: 20, paddingRight: 24, paddingBottom: 28 }}
          refreshControl={
            <RefreshControl
              refreshing={refreshing}
              onRefresh={async () => {
                setRefreshing(true);
                await load();
                setRefreshing(false);
              }}
            />
          }
        >
          <StickerCard color={palette.tintYellow} padding={18}>
            <View style={{ flexDirection: 'row', alignItems: 'center' }}>
              <StickerEmoji emoji="🪙" color={palette.surface} size={64} />
              <View style={{ flex: 1, marginLeft: 16 }}>
                <Text style={display(28, palette.ink, 700)}>
                  {balance} {balance === 1 ? 'coin' : 'coins'}
                </Text>
                <Text style={[body(14, palette.ink, 400, 1.35), { marginTop: 2 }]}>
                  Read, finish quizzes and make stories to earn more, {childName}!
                </Text>
              </View>
            </View>
          </StickerCard>
          <View style={{ height: 22 }} />
          {error ? (
            <View style={{ marginBottom: 18 }}>
              <ErrorNote message={error} center />
            </View>
          ) : null}
          {rewards.length === 0 ? (
            <StickerCard padding={24}>
              <View style={{ alignItems: 'center' }}>
                <StickerEmoji emoji="🎁" color={palette.tintMagenta} size={72} />
                <Text style={[display(18, palette.ink), { textAlign: 'center', marginTop: 14 }]}>
                  Ask a grown-up to add some rewards!
                </Text>
              </View>
            </StickerCard>
          ) : (
            rewards.map((r, i) => {
              const affordable = balance >= r.coinCost;
              const short = r.coinCost - balance;
              return (
                <View key={r.id} style={{ marginBottom: 20 }}>
                  <StickerCard padding={16}>
                    <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                      <StickerEmoji emoji="🎁" color={tintForIndex(palette, i + 1)} size={52} />
                      <View style={{ flex: 1, marginLeft: 14 }}>
                        <Text style={display(18, palette.ink, 700)}>{r.title}</Text>
                        {r.description ? (
                          <Text style={[body(14, palette.inkMuted, 400, 1.35), { marginTop: 2 }]}>{r.description}</Text>
                        ) : null}
                      </View>
                      <View style={{ marginLeft: 10 }}>
                        <StickerPill color={palette.tintYellow}>
                          <View style={{ alignItems: 'center' }}>
                            <Text style={display(20, palette.ink, 700)}>{r.coinCost}</Text>
                            <Text style={body(12, palette.ink, 400, 1.1)}>{r.coinCost === 1 ? 'coin' : 'coins'}</Text>
                          </View>
                        </StickerPill>
                      </View>
                    </View>
                    <View style={{ height: 14 }} />
                    {affordable ? (
                      <StoryButton label="Redeem" showArrow={false} onPress={redeeming ? null : () => redeem(r)} />
                    ) : (
                      <>
                        <View
                          style={{
                            height: 14,
                            borderRadius: 8,
                            borderWidth: outlineWidthThin,
                            borderColor: palette.outline,
                            backgroundColor: palette.track,
                            overflow: 'hidden',
                          }}
                        >
                          <View
                            style={{
                              width: `${Math.max(0, Math.min(1, balance / r.coinCost)) * 100}%`,
                              height: '100%',
                              backgroundColor: palette.action,
                            }}
                          />
                        </View>
                        <Text style={[body(14, palette.inkMuted), { marginTop: 6 }]}>
                          {short} more {short === 1 ? 'coin' : 'coins'} to go
                        </Text>
                      </>
                    )}
                  </StickerCard>
                </View>
              );
            })
          )}
          {requests.length > 0 && (
            <>
              <View style={{ height: 8 }} />
              <RowLabel text="My requests" align="left" />
              <View style={{ height: 10 }} />
              {requests.map((r) => {
                const [label, icon, tint]: [string, IconName, string] =
                  r.status === 'given'
                    ? ['Given', 'check', palette.tintGreen]
                    : r.status === 'declined'
                      ? ['Not this time, coins returned', 'undo', palette.surface]
                      : ['Waiting for a grown-up', 'hourglass-top', palette.tintYellow];
                return (
                  <View key={r.id} style={{ marginBottom: 12 }}>
                    <StickerCard radius={radiusButton} depth={3} padding={{ paddingHorizontal: 14, paddingVertical: 12 }}>
                      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                        <View
                          style={{
                            width: 40,
                            height: 40,
                            borderRadius: 20,
                            backgroundColor: tint,
                            borderWidth: outlineWidthThin,
                            borderColor: palette.outline,
                            alignItems: 'center',
                            justifyContent: 'center',
                          }}
                        >
                          <Icon name={icon} size={22} color={palette.ink} />
                        </View>
                        <View style={{ flex: 1, marginLeft: 14 }}>
                          <Text style={display(16, palette.ink, 700)}>{r.title}</Text>
                          <Text style={body(13, palette.inkMuted)}>{label}</Text>
                        </View>
                        <Text style={display(16, palette.ink, 700)}>{costOf(r)} 🪙</Text>
                      </View>
                    </StickerCard>
                  </View>
                );
              })}
            </>
          )}
        </ScrollView>
      )}
    </StickerPage>
  );
}

/** A paper sticker of a dialog with stacked full-width buttons. */
export function KidDialog({
  emoji,
  title,
  message,
  primary,
  onPrimary,
  secondary,
  onSecondary,
}: {
  emoji: string;
  title: string;
  message: string;
  primary: string;
  onPrimary: () => void;
  secondary?: string;
  onSecondary?: () => void;
}) {
  const palette = usePalette();
  return (
    <View
      style={{
        width: '100%',
        maxWidth: 420,
        backgroundColor: palette.surface,
        borderRadius: radiusTile,
        borderWidth: outlineWidth,
        borderColor: palette.outline,
        padding: 22,
        paddingTop: 24,
      }}
    >
      <View style={{ alignItems: 'center' }}>
        <StickerEmoji emoji={emoji} color={palette.tintYellow} size={72} />
      </View>
      <Text style={[display(22, palette.ink, 700), { textAlign: 'center', marginTop: 16 }]}>{title}</Text>
      <Text style={[body(16, palette.ink), { textAlign: 'center', marginTop: 8 }]}>{message}</Text>
      <View style={{ height: 22 }} />
      <StoryButton label={primary} showArrow={false} onPress={onPrimary} />
      {secondary ? (
        <>
          <View style={{ height: 12 }} />
          <StoryButton label={secondary} showArrow={false} filled={false} onPress={onSecondary} />
        </>
      ) : null}
    </View>
  );
}
