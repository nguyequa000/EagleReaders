import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Animated, ScrollView, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { PaperBackground } from '../components/PaperBackground';
import { BeadProgress, Icon, Spinner, SproutBubble, StickerCard, StickerHeader, StickerPill, StoryButton } from '../components/sticker';
import { useToast } from '../components/Toast';
import { useNav } from '../nav/Navigator';
import { ActivityService } from '../services/activity';
import { CoinService } from '../services/coins';
import { isQuotaError, type ComprehensionQuestion } from '../services/storyGenerator';
import { usePalette } from '../theme/ThemeProvider';
import { body, cardShadow, display, outlineWidth, outlineWidthThin, radiusButton, tintForIndex } from '../theme/palette';
import { useMounted } from './family';

/**
 * A short comprehension quiz: Sprout asks, the child taps an answer, the
 * right one turns green. Finishing logs the score and pays the quiz coins.
 */
export function ComprehensionScreen({
  childId,
  bookTitle,
  chapterNumber,
  questions: given,
  generateQuestions,
  chapterTitle,
  skippable = false,
}: {
  childId: string;
  childName: string;
  bookTitle: string;
  chapterNumber: number;
  questions?: ComprehensionQuestion[];
  generateQuestions?: () => Promise<ComprehensionQuestion[]>;
  chapterTitle?: string;
  skippable?: boolean;
}) {
  const palette = usePalette();
  const nav = useNav();
  const toast = useToast();
  const mounted = useMounted();
  const insets = useSafeAreaInsets();
  const [questions, setQuestions] = useState<ComprehensionQuestion[]>([]);
  const [index, setIndex] = useState(0);
  const [correct, setCorrect] = useState(0);
  const [selected, setSelected] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const saving = useRef(false);
  const fade = useRef(new Animated.Value(0)).current;

  const fadeIn = useCallback(() => {
    fade.setValue(0);
    Animated.timing(fade, { toValue: 1, duration: 400, useNativeDriver: true }).start();
  }, [fade]);

  const load = useCallback(async () => {
    try {
      const loaded = given ?? (generateQuestions ? await generateQuestions() : []);
      if (!mounted.current) return;
      setQuestions(loaded);
      setLoading(false);
      fadeIn();
    } catch (e) {
      if (!mounted.current) return;
      setError(isQuotaError(e) ? 'Sprout needs a short rest. Try again in a minute!' : "Sprout couldn't think of questions right now.");
      setLoading(false);
    }
  }, [fadeIn, generateQuestions, given, mounted]);

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const current = questions[index];
  const answered = selected != null;
  const isLast = index === questions.length - 1;

  const choose = (i: number) => {
    if (answered) return;
    setSelected(i);
    if (i === current.correctIndex) setCorrect((c) => c + 1);
  };

  const advance = async () => {
    if (!answered || saving.current) return;
    if (!isLast) {
      setIndex((i) => i + 1);
      setSelected(null);
      fadeIn();
      return;
    }
    saving.current = true;
    try {
      await ActivityService.logEvent(childId, 'comprehension_result', {
        title: bookTitle,
        chapter: chapterNumber,
        ...(chapterTitle ? { chapterTitle } : {}),
        score: `${correct}/${questions.length}`,
        correct,
        total: questions.length,
      });
    } catch {
      // The child still gets back to the book.
    } finally {
      saving.current = false;
    }
    try {
      const coins = await CoinService.awardQuiz(childId, bookTitle);
      if (coins > 0) toast.coins(coins);
    } catch {
      // A failed award must never stop the child getting back to the book.
    }
    nav.pop();
  };

  const message = (text: string, retry?: () => void) => (
    <ScrollView contentContainerStyle={{ flexGrow: 1, justifyContent: 'center', padding: 24 }}>
      <SproutBubble message={text} />
      <View style={{ height: 24 }} />
      {retry && (
        <>
          <StoryButton label="Retry" showArrow={false} onPress={retry} />
          <View style={{ height: 14 }} />
        </>
      )}
      <StoryButton label="Keep Reading →" filled={!retry} showArrow={false} onPress={() => nav.pop()} />
    </ScrollView>
  );

  return (
    <PaperBackground>
      <StickerHeader
        title={chapterTitle ?? `End of Chapter ${chapterNumber}`}
        showBack
        trailing={
          skippable ? (
            <StickerPill onPress={() => nav.pop()}>
              <Text style={display(15, palette.ink, 700)}>Skip</Text>
            </StickerPill>
          ) : null
        }
      />
      <View style={{ flex: 1 }}>
        {loading ? (
          <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
            <View
              style={{
                width: 84,
                height: 84,
                borderRadius: 42,
                backgroundColor: palette.tintGreen,
                borderWidth: outlineWidth,
                borderColor: palette.outline,
                alignItems: 'center',
                justifyContent: 'center',
                ...cardShadow(palette),
              }}
            >
              <Text style={{ fontSize: 42 }}>🌱</Text>
            </View>
            <View style={{ height: 20 }} />
            <Spinner />
            <Text style={[display(17, palette.ink, 600), { marginTop: 16 }]}>Sprout is thinking of questions…</Text>
          </View>
        ) : error ? (
          message(error, () => {
            setError(null);
            setLoading(true);
            load();
          })
        ) : questions.length === 0 ? (
          message('No questions for this chapter yet.')
        ) : (
          <Animated.View style={{ flex: 1, opacity: fade }}>
            <ScrollView contentContainerStyle={{ padding: 20, paddingTop: 16, paddingBottom: 12 }}>
              <BeadProgress
                label={`QUESTION ${index + 1} OF ${questions.length}`}
                total={questions.length}
                done={(i) => i < index || (i === index && answered)}
              />
              <View style={{ height: 20 }} />
              <SproutBubble message={current.question} />
              <View style={{ height: 24 }} />
              {current.answers.map((answer, i) => {
                const isCorrect = answered && i === current.correctIndex;
                const isWrong = answered && i === selected && i !== current.correctIndex;
                const fill = isCorrect
                  ? palette.tintGreen
                  : isWrong
                    ? palette.tintCoral
                    : answered
                      ? palette.surface
                      : tintForIndex(palette, i);
                return (
                  <View key={`${index}-${i}`} style={{ marginBottom: 14 }}>
                    <StickerCard
                      color={fill}
                      radius={radiusButton}
                      selected={selected === i}
                      onPress={answered ? undefined : () => choose(i)}
                      accessibilityLabel={answer}
                      padding={14}
                    >
                      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                        <View
                          style={{
                            width: 30,
                            height: 30,
                            borderRadius: 15,
                            backgroundColor: palette.surface,
                            borderWidth: outlineWidthThin,
                            borderColor: palette.outline,
                            alignItems: 'center',
                            justifyContent: 'center',
                          }}
                        >
                          {isCorrect ? (
                            <Icon name="check" size={18} color={palette.ink} />
                          ) : isWrong ? (
                            <Icon name="close" size={18} color={palette.ink} />
                          ) : (
                            <Text style={display(15, palette.ink, 700)}>{String.fromCharCode(65 + i)}</Text>
                          )}
                        </View>
                        <Text
                          style={[
                            body(16, answered && !isCorrect && !isWrong ? palette.inkMuted : palette.ink, 700, 1.35),
                            { flex: 1, marginLeft: 12 },
                          ]}
                        >
                          {answer}
                        </Text>
                      </View>
                    </StickerCard>
                  </View>
                );
              })}
            </ScrollView>
            <View style={{ paddingHorizontal: 20, paddingTop: 8, paddingBottom: insets.bottom + 18, opacity: answered ? 1 : 0 }}>
              <StoryButton
                label={isLast ? 'Keep Reading →' : 'Next Question →'}
                showArrow={false}
                onPress={answered ? advance : null}
              />
            </View>
          </Animated.View>
        )}
      </View>
    </PaperBackground>
  );
}
