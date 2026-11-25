package com.hilalsafi.cryptoclicker.ui.trophies

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.StartOffset
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Description
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Redeem
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hilalsafi.cryptoclicker.core.Achievement
import com.hilalsafi.cryptoclicker.core.Achievements
import com.hilalsafi.cryptoclicker.core.Daily
import com.hilalsafi.cryptoclicker.core.DailyReward
import com.hilalsafi.cryptoclicker.core.Goal
import com.hilalsafi.cryptoclicker.core.Goals
import com.hilalsafi.cryptoclicker.core.Quest
import com.hilalsafi.cryptoclicker.core.Starter
import com.hilalsafi.cryptoclicker.ui.LocalGame
import com.hilalsafi.cryptoclicker.ui.Requests
import com.hilalsafi.cryptoclicker.ui.WantViews
import com.hilalsafi.cryptoclicker.ui.design.AutoSizeText
import com.hilalsafi.cryptoclicker.ui.design.Emoji
import com.hilalsafi.cryptoclicker.ui.design.ProgressBar
import com.hilalsafi.cryptoclicker.ui.design.ProminentButton
import com.hilalsafi.cryptoclicker.ui.design.SegmentedPicker
import com.hilalsafi.cryptoclicker.ui.design.Symbol
import com.hilalsafi.cryptoclicker.ui.design.TabTitle
import com.hilalsafi.cryptoclicker.ui.design.TierStars
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.design.bold
import com.hilalsafi.cryptoclicker.ui.design.digits
import com.hilalsafi.cryptoclicker.ui.design.relativeTime
import com.hilalsafi.cryptoclicker.ui.design.rememberFeedback
import com.hilalsafi.cryptoclicker.ui.design.rememberNow
import com.hilalsafi.cryptoclicker.ui.design.semibold
import com.hilalsafi.cryptoclicker.ui.theme.AppBackground
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.cardSurface
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import com.hilalsafi.cryptoclicker.ui.theme.glassCard
import com.hilalsafi.cryptoclicker.ui.theme.rowCard

private enum class TrophiesPage(val title: String, val view: String) {
    Goals("Goals", "goals"),
    Daily("Daily", "daily"),
    Achievements("Achievements", "achievements"),
}

/** What to work toward next, daily rewards and quests, and the achievements that add production (iOS: TrophiesView). */
@Composable
fun TrophiesScreen(contentPadding: PaddingValues, requests: Requests, openChallenge: (String?) -> Unit) {
    val game = LocalGame.current
    var page by rememberSaveable { mutableStateOf(TrophiesPage.Daily) }
    LaunchedEffect(requests.daily) {
        if (requests.daily) {
            requests.daily = false
            page = TrophiesPage.Daily
        }
    }
    when (page) {
        TrophiesPage.Goals -> WantViews("goals")
        TrophiesPage.Daily -> WantViews("daily")
        TrophiesPage.Achievements -> WantViews("achievements")
    }
    val view by game.game.collectAsState()
    val badge = view?.dailyBadge ?: 0
    val starterClaims = view?.starterClaims ?: 0
    Box(Modifier.fillMaxSize()) {
        AppBackground(Palette.trophies)
        BoxWithConstraints(Modifier.fillMaxSize()) {
            // Achievement cards at least 160 wide, as many to a row as fit.
            val width = minOf(maxWidth, 900.dp) - 32.dp
            val columns = maxOf(1, ((width + 12.dp) / (160.dp + 12.dp)).toInt())
            LazyColumn(
                Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = contentPadding.calculateBottomPadding() + 24.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                item(key = "title") { TabTitle("Trophies", Modifier.statusBarsPadding()) }
                item(key = "page") {
                    SegmentedPicker(TrophiesPage.entries, page, {
                        when {
                            it == TrophiesPage.Daily && badge > 0 -> "${it.title} ($badge)"
                            it == TrophiesPage.Goals && starterClaims > 0 -> "${it.title} ($starterClaims)"
                            else -> it.title
                        }
                    }, { page = it }, Modifier.widthIn(max = 900.dp))
                }
                when (page) {
                    TrophiesPage.Goals -> view?.goals?.let { goalsPage(it) }
                    TrophiesPage.Daily -> view?.daily?.let { dailyPage(it, openChallenge) }
                    TrophiesPage.Achievements -> view?.achievements?.let { achievementsPage(it, columns) }
                }
            }
        }
    }
}

@Composable
private fun Wide(content: @Composable () -> Unit) {
    Box(Modifier.fillMaxWidth().widthIn(max = 900.dp)) { content() }
}

// MARK: - Goals

/** The opening's starter milestones (until every one is claimed), then the next few things worth working toward. */
private fun LazyListScope.goalsPage(goals: Goals) {
    if (goals.starters.isNotEmpty()) {
        item(key = "startersTitle") { Wide { Text("Starter milestones", style = Type.title3.bold, modifier = Modifier.padding(horizontal = 4.dp)) } }
        items(goals.starters, key = { "starter:${it.id}" }) { starter -> Wide { StarterCard(starter) } }
    }
    item(key = "goalsTitle") { Wide { Text("Your next goals", style = Type.title3.bold, modifier = Modifier.padding(horizontal = 4.dp)) } }
    items(goals.goals, key = { "goal:${it.id}" }) { goal -> Wide { GoalCard(goal) } }
}

/** One starter milestone: what to do, what it pays, and Claim once it's done (iOS: StarterMilestoneCard). */
@Composable
private fun StarterCard(starter: Starter) {
    val colors = gameColors
    val game = LocalGame.current
    val feedback = rememberFeedback()
    val fill = if (starter.isClaimed) colors.gain else colors.accent
    Row(
        Modifier.fillMaxWidth().alpha(if (starter.isClaimed) 0.7f else 1f).rowCard(colors).semantics(mergeDescendants = true) {},
        horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(46.dp).clip(CircleShape).background(Brush.verticalGradient(listOf(fill.copy(alpha = 0.85f), fill))), contentAlignment = Alignment.Center) {
            Symbol(if (starter.isClaimed) "checkmark" else starter.symbol, tint = Color.White, size = 22.dp)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
            Text(starter.title, style = Type.headline)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Symbol(if (starter.rewardKind == "bullRun") "flame.fill" else "bitcoinsign.circle.fill", tint = colors.subtext, size = 15.dp)
                Text(starter.reward, style = Type.subheadline, color = colors.subtext)
            }
            if (!starter.isReached) ProgressBar(starter.progress.toFloat(), colors.accent)
        }
        when {
            starter.isClaimed -> Text("Claimed", style = Type.subheadline.semibold, color = colors.gain)
            starter.isReached -> ProminentButton(
                "Claim", onClick = {
                    feedback.success()
                    game.command("claimStarter", mapOf("id" to starter.id))
                },
                style = Type.subheadline.bold, contentPadding = PaddingValues(horizontal = 14.dp, vertical = 6.dp),
            )
        }
    }
}

@Composable
private fun GoalCard(goal: Goal) {
    val colors = gameColors
    val tint = Palette.named(goal.color)
    Row(Modifier.fillMaxWidth().rowCard(colors).semantics(mergeDescendants = true) {}, horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(46.dp).clip(CircleShape).background(Brush.verticalGradient(listOf(tint.copy(alpha = 0.85f), tint))), contentAlignment = Alignment.Center) {
            Symbol(goal.symbol, tint = Color.White, size = 22.dp)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
            Row(verticalAlignment = Alignment.Top) {
                Text(goal.title, style = Type.headline, modifier = Modifier.weight(1f).padding(end = 8.dp))
                Text(goal.progressText, style = Type.subheadline.bold.digits, color = if (goal.ready) colors.gain else tint)
            }
            Text(goal.detail, style = Type.subheadline, color = colors.subtext)
            ProgressBar(goal.progress.toFloat(), tint)
        }
    }
}

// MARK: - Daily

private fun LazyListScope.dailyPage(daily: Daily, openChallenge: (String?) -> Unit) {
    item(key = "reward") { Wide { DailyRewardCard(daily.reward, daily.resetsAt) } }
    item(key = "quests") { Wide { QuestsCard(daily) } }
    daily.challenge?.let { challenge ->
        item(key = "challenge") { Wide { ChallengeCard(challenge, play = if (challenge.canPlay) ({ openChallenge(challenge.game) }) else null) } }
    }
    item(key = "dailyNote") {
        Wide { Text(daily.footnote, style = Type.subheadline, color = gameColors.subtext, modifier = Modifier.padding(horizontal = 4.dp)) }
    }
}

/** The login streak: a week of rewards building to day 7, and today's to claim (iOS: DailyRewardCard). */
@Composable
private fun DailyRewardCard(reward: DailyReward, resetsAt: Double) {
    val game = LocalGame.current
    val colors = gameColors
    val feedback = rememberFeedback()
    val now by rememberNow()
    Column(Modifier.fillMaxWidth().glassCard(colors, tint = Palette.trophies), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Icon(Icons.Rounded.Redeem, null, modifier = Modifier.size(22.dp))
            Text("Daily Reward", style = Type.title3.bold, modifier = Modifier.weight(1f))
            reward.streak?.let { Text(it, style = Type.subheadline.semibold, color = colors.subtext) }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            reward.days.forEach { day ->
                Column(
                    Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(12.dp))
                        .background(if (day.isToday) colors.accent.copy(alpha = 0.16f) else colors.subtext.copy(alpha = 0.08f))
                        .padding(vertical = 8.dp)
                        .semantics { contentDescription = "Day ${day.day}" + (if (day.isClaimed) ", claimed" else "") + (if (day.isToday) ", today" else "") },
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Symbol(day.symbol, tint = if (day.isClaimed) Palette.green else if (day.isToday) colors.accent else colors.subtext, size = 22.dp)
                    AutoSizeText("Day ${day.day}", Type.footnote.bold, color = if (day.isToday) colors.accent else colors.text, minScale = 0.7f)
                }
            }
        }
        if (reward.isReady) {
            androidx.compose.material3.Button(
                onClick = {
                    game.command("claimDailyReward")
                    feedback.success()
                },
                modifier = Modifier.fillMaxWidth(),
                shape = CircleShape,
                colors = androidx.compose.material3.ButtonDefaults.buttonColors(containerColor = colors.accent, contentColor = Color.White),
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(reward.claimTitle, style = Type.headline)
                    Text(reward.claimDetail, style = Type.subheadline.digits)
                }
            }
        } else {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Rounded.Schedule, null, tint = colors.subtext, modifier = Modifier.size(16.dp))
                Text("${reward.waitWord} reward in ${relativeTime(resetsAt - now)}", style = Type.subheadline.semibold.digits, color = colors.subtext)
            }
        }
        reward.note?.let { Text(it, style = Type.subheadline, color = colors.subtext) }
    }
}

@Composable
private fun QuestsCard(daily: Daily) {
    val colors = gameColors
    val now by rememberNow()
    Column(Modifier.fillMaxWidth().rowCard(colors), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Icon(Icons.Rounded.Description, null, modifier = Modifier.size(20.dp))
            Text("Today's Quests", style = Type.headline, modifier = Modifier.weight(1f))
            Text("New in ${relativeTime(daily.resetsAt - now)}", style = Type.subheadline.semibold.digits, color = colors.accent)
        }
        daily.questsEmpty?.let { Text(it, style = Type.subheadline, color = colors.subtext) }
        daily.quests.forEachIndexed { index, quest ->
            QuestRow(quest)
            if (index < daily.quests.lastIndex) HorizontalDivider()
        }
    }
}

@Composable
private fun QuestRow(quest: Quest) {
    val game = LocalGame.current
    val colors = gameColors
    val feedback = rememberFeedback()
    Row(Modifier.fillMaxWidth().alpha(if (quest.isClaimed) 0.7f else 1f), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(
            Modifier.size(38.dp).clip(CircleShape).background(if (quest.isComplete) colors.accent else colors.accent.copy(alpha = 0.14f)),
            contentAlignment = Alignment.Center,
        ) {
            Symbol(quest.symbol, tint = if (quest.isComplete) Color.White else colors.accent, size = 20.dp)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(quest.title, style = Type.subheadline.semibold)
            ProgressBar(quest.fraction.toFloat(), colors.accent)
            // Progress and reward side by side, or the reward under the progress when it's long.
            BoxWithConstraints(Modifier.fillMaxWidth()) {
                val stacked = (quest.progressText.length + quest.reward.length) * 8.5f + 40 > maxWidth.value
                val progress: @Composable () -> Unit = {
                    Text(quest.progressText, style = Type.subheadline.semibold.digits, color = colors.subtext, maxLines = 1)
                }
                val rewardLabel: @Composable () -> Unit = {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        Symbol(quest.rewardSymbol, tint = colors.accent, size = 14.dp)
                        Text(quest.reward, style = Type.subheadline.semibold, color = colors.accent, maxLines = 1)
                    }
                }
                if (stacked) {
                    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) { progress(); rewardLabel() }
                } else {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        progress()
                        Spacer(Modifier.weight(1f))
                        rewardLabel()
                    }
                }
            }
        }
        when {
            quest.isClaimed -> Icon(Icons.Rounded.CheckCircle, "Claimed", tint = Palette.green, modifier = Modifier.size(28.dp))
            quest.isComplete -> ProminentButton("Claim", onClick = {
                game.command("claimQuest", mapOf("id" to quest.id))
                feedback.success()
            }, style = Type.subheadline.bold, contentPadding = PaddingValues(horizontal = 14.dp, vertical = 6.dp))
        }
    }
}

// MARK: - Achievements

private fun LazyListScope.achievementsPage(achievements: Achievements, columns: Int) {
    item(key = "summary") { Wide { TrophySummary(achievements) } }
    val rows = achievements.cards.chunked(columns)
    items(rows, key = { row -> "achievements:${row.first().id}" }) { row ->
        Wide {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                row.forEach { AchievementCard(it, Modifier.weight(1f)) }
                repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

@Composable
private fun TrophySummary(achievements: Achievements) {
    val colors = gameColors
    Row(Modifier.fillMaxWidth().glassCard(colors, tint = Palette.trophies).semantics(mergeDescendants = true) {},
        horizontalArrangement = Arrangement.spacedBy(16.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(Icons.Rounded.EmojiEvents, null, tint = Palette.trophies, modifier = Modifier.size(44.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(achievements.title, style = Type.title3.bold)
            Text(achievements.bonus, style = Type.subheadline, color = colors.subtext)
            ProgressBar(achievements.fraction.toFloat(), Palette.trophies)
            achievements.nextFinish?.let { Text(it, style = Type.subheadline.semibold, color = colors.accent) }
        }
    }
}

/**
 * One achievement: its stars and progress toward the next tier (iOS: AchievementCard). Earned
 * cards take on the metal of their highest tier with a shine sweeping across now and then; mythic
 * cards are iridescent.
 */
@Composable
private fun AchievementCard(achievement: Achievement, modifier: Modifier) {
    val colors = gameColors
    val shape = RoundedCornerShape(20.dp)
    val tier = achievement.tiers - 1
    val background = if (achievement.tiers == 0) {
        Modifier.cardSurface(colors, 20.dp)
    } else {
        Modifier.metalCard(tier, achievement.id, colors.isDark)
    }
    Column(
        modifier
            .then(background)
            .clip(shape)
            .padding(14.dp)
            .alpha(if (achievement.tiers == 0) 0.75f else 1f)
            .semantics(mergeDescendants = true) { contentDescription = "${achievement.name}, ${achievement.tierName}, ${achievement.progressText}" },
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Emoji(achievement.emoji, 26.sp)
            Spacer(Modifier.weight(1f))
            TierStars(achievement.tiers)
        }
        AutoSizeText(achievement.name, Type.headline, minScale = 0.8f)
        Text(achievement.detail, style = Type.subheadline, color = colors.subtext, maxLines = 2, minLines = 2)
        ProgressBar(achievement.fraction.toFloat(), Palette.tierColor(if (achievement.isMythic) 3 else achievement.tiers.coerceAtMost(3)))
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            if (achievement.isMythic) Icon(Icons.Rounded.AutoAwesome, null, tint = Palette.tierColor(3), modifier = Modifier.size(14.dp))
            AutoSizeText(achievement.progressText, Type.subheadline.semibold.digits, minScale = 0.8f)
        }
    }
}

/** A steady offset per achievement, so cards side by side shine at different moments (iOS: AchievementCard.delay). */
private fun shineDelay(id: String): Int {
    var hash = 0
    for (char in id) hash = (hash * 31 + char.code) % 997
    return (hash % 40) * 100
}

/** Seconds between shines, and how bright the sweep is, per tier (iOS: TierStyle). */
private fun shinePeriod(tier: Int) = when (tier) {
    0 -> 9_000
    1 -> 8_000
    2 -> 7_000
    else -> 3_200
}

private fun shineIntensity(tier: Int) = when (tier) {
    0 -> 0.12f
    1 -> 0.17f
    2 -> 0.22f
    else -> 0.7f
}

/** An earned card's look: the tier's metal over the card, a shine sweeping across, and a metal border. */
@Composable
private fun Modifier.metalCard(tier: Int, id: String, isDark: Boolean): Modifier {
    val colors = gameColors
    val shape = RoundedCornerShape(20.dp)
    val mythic = tier >= 3
    val metal = Palette.metal(tier.coerceAtMost(3))
    val transition = rememberInfiniteTransition(label = "shine")
    val sweep by transition.animateFloat(
        0f, 1f,
        infiniteRepeatable(tween(shinePeriod(tier), easing = LinearEasing), RepeatMode.Restart, StartOffset(shineDelay(id))),
        label = "sweep",
    )
    val turn by transition.animateFloat(0f, 360f, infiniteRepeatable(tween(6_000, easing = LinearEasing)), label = "turn")
    val intensity = shineIntensity(tier)
    val glow = if (mythic) Palette.tierColor(3) else metal[1]
    return this
        .shadow(if (tier >= 2) 10.dp else 6.dp, shape, ambientColor = glow.copy(alpha = if (isDark) 0.45f else 0.35f), spotColor = glow.copy(alpha = if (isDark) 0.45f else 0.35f))
        .background(colors.card, shape)
        .drawWithContent {
            // The metal tint, then the sweep of light, under the content.
            if (mythic) {
                rotate(turn) {
                    drawCircle(Brush.sweepGradient(Palette.mythic, center), radius = size.maxDimension, center = center, alpha = if (isDark) 0.32f else 0.26f)
                }
            } else {
                drawRect(Brush.linearGradient(metal, Offset.Zero, Offset(size.width, size.height)), alpha = if (isDark) 0.34f else 0.30f)
            }
            val band = maxOf(32.dp.toPx(), size.width * 0.22f)
            // Travels well past the right edge, so each sweep is followed by a pause.
            val x = -size.width * 0.6f + sweep * size.width * 3.2f
            rotate(18f, Offset(x + band / 2, size.height / 2)) {
                drawRect(
                    Brush.horizontalGradient(listOf(Color.Transparent, Color.White.copy(alpha = intensity), Color.Transparent), startX = x, endX = x + band),
                    topLeft = Offset(x, -size.height * 0.5f), size = androidx.compose.ui.geometry.Size(band, size.height * 2), blendMode = BlendMode.Plus,
                )
            }
            drawContent()
        }
        .border(
            if (mythic) 3.dp else 2.dp,
            if (mythic) Brush.sweepGradient(Palette.mythic) else Brush.linearGradient(metal),
            shape,
        )
}

