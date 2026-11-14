package com.hilalsafi.cryptoclicker.ui.design

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.automirrored.rounded.DirectionsRun
import androidx.compose.material.icons.automirrored.rounded.DirectionsWalk
import androidx.compose.material.icons.automirrored.rounded.HelpOutline
import androidx.compose.material.icons.automirrored.rounded.ListAlt
import androidx.compose.material.icons.automirrored.rounded.TrendingDown
import androidx.compose.material.icons.automirrored.rounded.TrendingUp
import androidx.compose.material.icons.automirrored.rounded.Undo
import androidx.compose.material.icons.rounded.AcUnit
import androidx.compose.material.icons.rounded.AccountBalance
import androidx.compose.material.icons.rounded.AccountBalanceWallet
import androidx.compose.material.icons.rounded.AccountTree
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.AddBox
import androidx.compose.material.icons.rounded.AddCircle
import androidx.compose.material.icons.rounded.Apps
import androidx.compose.material.icons.rounded.ArrowCircleUp
import androidx.compose.material.icons.rounded.ArrowDownward
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.BarChart
import androidx.compose.material.icons.rounded.Bedtime
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.BugReport
import androidx.compose.material.icons.rounded.Build
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.Casino
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.ChevronLeft
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.Dangerous
import androidx.compose.material.icons.rounded.Description
import androidx.compose.material.icons.rounded.Dns
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Event
import androidx.compose.material.icons.rounded.EventAvailable
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.Flag
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.Flare
import androidx.compose.material.icons.rounded.FlightTakeoff
import androidx.compose.material.icons.rounded.Gavel
import androidx.compose.material.icons.rounded.FlashOff
import androidx.compose.material.icons.rounded.Gesture
import androidx.compose.material.icons.rounded.GpsFixed
import androidx.compose.material.icons.rounded.GraphicEq
import androidx.compose.material.icons.rounded.GridView
import androidx.compose.material.icons.rounded.Hiking
import androidx.compose.material.icons.rounded.History
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.Keyboard
import androidx.compose.material.icons.rounded.Landscape
import androidx.compose.material.icons.rounded.Layers
import androidx.compose.material.icons.rounded.Lightbulb
import androidx.compose.material.icons.rounded.Link
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.LocalGasStation
import androidx.compose.material.icons.rounded.LocalOffer
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.LockOpen
import androidx.compose.material.icons.rounded.Memory
import androidx.compose.material.icons.rounded.MilitaryTech
import androidx.compose.material.icons.rounded.MonetizationOn
import androidx.compose.material.icons.rounded.Mouse
import androidx.compose.material.icons.rounded.MoveToInbox
import androidx.compose.material.icons.rounded.NightsStay
import androidx.compose.material.icons.rounded.NorthEast
import androidx.compose.material.icons.rounded.OpenInFull
import androidx.compose.material.icons.rounded.OpenInNew
import androidx.compose.material.icons.rounded.Palette
import androidx.compose.material.icons.rounded.PanTool
import androidx.compose.material.icons.rounded.PauseCircle
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.PersonAdd
import androidx.compose.material.icons.rounded.PieChart
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Psychology
import androidx.compose.material.icons.rounded.RadioButtonUnchecked
import androidx.compose.material.icons.rounded.Redeem
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Replay
import androidx.compose.material.icons.rounded.Report
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material.icons.rounded.Science
import androidx.compose.material.icons.rounded.Sensors
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.Shield
import androidx.compose.material.icons.rounded.ShoppingBag
import androidx.compose.material.icons.rounded.ShoppingCart
import androidx.compose.material.icons.rounded.ShowChart
import androidx.compose.material.icons.rounded.Speed
import androidx.compose.material.icons.rounded.SportsEsports
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.StarBorder
import androidx.compose.material.icons.rounded.Stars
import androidx.compose.material.icons.rounded.Storage
import androidx.compose.material.icons.rounded.Style
import androidx.compose.material.icons.rounded.SwapHoriz
import androidx.compose.material.icons.rounded.Sync
import androidx.compose.material.icons.rounded.Timeline
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material.icons.rounded.Toys
import androidx.compose.material.icons.rounded.TrackChanges
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material.icons.rounded.UnfoldMore
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material.icons.rounded.VerticalAlignBottom
import androidx.compose.material.icons.rounded.ViewModule
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material.icons.rounded.WaterDrop
import androidx.compose.material.icons.rounded.WbSunny
import androidx.compose.material.icons.rounded.Widgets
import androidx.compose.ui.graphics.vector.ImageVector

/**
 * The SF Symbols the game and its screens name, as the closest Material icons. SF Symbols are
 * licensed for Apple platforms only, so Android draws its own icons in their place.
 */
object Symbols {
    private val table: Map<String, ImageVector> by lazy {
        mapOf(
        "play" to Icons.Rounded.PlayArrow,
        "sparkles" to Icons.Rounded.AutoAwesome,
        "sparkle" to Icons.Rounded.AutoAwesome,
        "wand.and.stars" to Icons.Rounded.AutoAwesome,
        "checkmark" to Icons.Rounded.Check,
        "checkmark.seal" to Icons.Rounded.Verified,
        "star" to Icons.Rounded.Star,
        "star.circle" to Icons.Rounded.Stars,
        "flame" to Icons.Rounded.LocalFireDepartment,
        "info" to Icons.Rounded.Info,
        "xmark" to Icons.Rounded.Close,
        "multiply" to Icons.Rounded.Close,
        "xmark.octagon" to Icons.Rounded.Dangerous,
        "lightbulb" to Icons.Rounded.Lightbulb,
        "gift" to Icons.Rounded.Redeem,
        "figure.walk" to Icons.AutoMirrored.Rounded.DirectionsWalk,
        "shoeprints" to Icons.AutoMirrored.Rounded.DirectionsWalk,
        "figure.run" to Icons.AutoMirrored.Rounded.DirectionsRun,
        "figure.hiking" to Icons.Rounded.Hiking,
        "figure.climbing" to Icons.Rounded.Hiking,
        "trophy" to Icons.Rounded.EmojiEvents,
        "lock" to Icons.Rounded.Lock,
        "lock.open" to Icons.Rounded.LockOpen,
        "lock.shield" to Icons.Rounded.Shield,
        "hand.tap" to Icons.Rounded.TouchApp,
        "hand.point.up.left" to Icons.Rounded.TouchApp,
        "hand.point.up" to Icons.Rounded.TouchApp,
        "hand.point.up.braille" to Icons.Rounded.TouchApp,
        "hand.raised" to Icons.Rounded.PanTool,
        "hand.raised.fingers.spread" to Icons.Rounded.PanTool,
        "hand.draw" to Icons.Rounded.Gesture,
        "flag.checkered" to Icons.Rounded.Flag,
        "flag" to Icons.Rounded.Flag,
        "bitcoinsign" to Icons.Rounded.MonetizationOn,
        "bitcoinsign.square" to Icons.Rounded.MonetizationOn,
        "dollarsign" to Icons.Rounded.MonetizationOn,
        "arrow.counterclockwise" to Icons.AutoMirrored.Rounded.Undo,
        "arrow.uturn.backward" to Icons.AutoMirrored.Rounded.Undo,
        "arrow.clockwise" to Icons.Rounded.Refresh,
        "target" to Icons.Rounded.GpsFixed,
        "shield" to Icons.Rounded.Shield,
        "rosette" to Icons.Rounded.MilitaryTech,
        "crown" to Icons.Rounded.EmojiEvents,
        "questionmark" to Icons.AutoMirrored.Rounded.HelpOutline,
        "questionmark.circle" to Icons.AutoMirrored.Rounded.HelpOutline,
        "moon.zzz" to Icons.Rounded.Bedtime,
        "moon" to Icons.Rounded.Bedtime,
        "moon.stars" to Icons.Rounded.NightsStay,
        "gamecontroller" to Icons.Rounded.SportsEsports,
        "chevron.right" to Icons.Rounded.ChevronRight,
        "chevron.left" to Icons.Rounded.ChevronLeft,
        "chevron.down" to Icons.Rounded.ExpandMore,
        "chevron.up.chevron.down" to Icons.Rounded.UnfoldMore,
        "chart.line.uptrend.xyaxis" to Icons.AutoMirrored.Rounded.TrendingUp,
        "chart.line.downtrend.xyaxis" to Icons.AutoMirrored.Rounded.TrendingDown,
        "chart.xyaxis.line" to Icons.Rounded.ShowChart,
        "chart.pie" to Icons.Rounded.PieChart,
        "chart.bar" to Icons.Rounded.BarChart,
        "bolt" to Icons.Rounded.Bolt,
        "bolt.slash" to Icons.Rounded.FlashOff,
        "arrow.right" to Icons.AutoMirrored.Rounded.ArrowForward,
        "arrow.left" to Icons.AutoMirrored.Rounded.ArrowBack,
        "arrow.down" to Icons.Rounded.ArrowDownward,
        "arrow.down.to.line" to Icons.Rounded.VerticalAlignBottom,
        "arrow.up" to Icons.Rounded.ArrowCircleUp,
        "arrow.up.forward" to Icons.Rounded.NorthEast,
        "arrow.up.forward.square" to Icons.Rounded.OpenInNew,
        "arrow.up.left.and.arrow.down.right" to Icons.Rounded.OpenInFull,
        "arrow.triangle.2.circlepath" to Icons.Rounded.Sync,
        "arrow.triangle.branch" to Icons.Rounded.AccountTree,
        "arrow.left.arrow.right" to Icons.Rounded.SwapHoriz,
        "arrow.left.and.right" to Icons.Rounded.SwapHoriz,
        "wallet.bifold" to Icons.Rounded.AccountBalanceWallet,
        "tray.and.arrow.down" to Icons.Rounded.MoveToInbox,
        "timer" to Icons.Rounded.Timer,
        "clock" to Icons.Rounded.Schedule,
        "clock.arrow.circlepath" to Icons.Rounded.History,
        "square.grid.2x2" to Icons.Rounded.GridView,
        "square.grid.3x3" to Icons.Rounded.Apps,
        "square.grid.3x3.middle.filled" to Icons.Rounded.ViewModule,
        "square.stack" to Icons.Rounded.Layers,
        "square.fill.on.square" to Icons.Rounded.ContentCopy,
        "snowflake" to Icons.Rounded.AcUnit,
        "slider.horizontal.3" to Icons.Rounded.Tune,
        "scroll" to Icons.Rounded.Description,
        "doc.text" to Icons.Rounded.Description,
        "newspaper" to Icons.Rounded.Description,
        "point.topleft.down.to.point.bottomright.curvepath" to Icons.Rounded.Timeline,
        "plus" to Icons.Rounded.Add,
        "plus.circle" to Icons.Rounded.AddCircle,
        "plus.square" to Icons.Rounded.AddBox,
        "person" to Icons.Rounded.Person,
        "person.fill.badge.plus" to Icons.Rounded.PersonAdd,
        "person.badge.plus" to Icons.Rounded.PersonAdd,
        "pause" to Icons.Rounded.PauseCircle,
        "paintpalette" to Icons.Rounded.Palette,
        "list.bullet.rectangle" to Icons.AutoMirrored.Rounded.ListAlt,
        "link" to Icons.Rounded.Link,
        "ladybug" to Icons.Rounded.BugReport,
        "gearshape" to Icons.Rounded.Settings,
        "gearshape.2" to Icons.Rounded.Settings,
        "exclamationmark.triangle" to Icons.Rounded.Warning,
        "exclamationmark.octagon" to Icons.Rounded.Report,
        "dice" to Icons.Rounded.Casino,
        "suit.spade" to Icons.Rounded.Casino,
        "circle.hexagongrid" to Icons.Rounded.Widgets,
        "circle.dotted" to Icons.Rounded.RadioButtonUnchecked,
        "cart" to Icons.Rounded.ShoppingCart,
        "bag" to Icons.Rounded.ShoppingBag,
        "bag.fill.badge.plus" to Icons.Rounded.ShoppingBag,
        "bag.badge.plus" to Icons.Rounded.ShoppingBag,
        "shippingbox" to Icons.Rounded.ShoppingBag,
        "calendar" to Icons.Rounded.Event,
        "calendar.badge.checkmark" to Icons.Rounded.EventAvailable,
        "building.columns" to Icons.Rounded.AccountBalance,
        "binoculars" to Icons.Rounded.Visibility,
        "brain" to Icons.Rounded.Psychology,
        "brain.head.profile" to Icons.Rounded.Psychology,
        "dot.radiowaves.left.and.right" to Icons.Rounded.Sensors,
        "fanblades" to Icons.Rounded.Toys,
        "fuelpump" to Icons.Rounded.LocalGasStation,
        "gauge.with.dots.needle.33percent" to Icons.Rounded.Speed,
        "speedometer" to Icons.Rounded.Speed,
        "tag" to Icons.Rounded.LocalOffer,
        "wrench.and.screwdriver" to Icons.Rounded.Build,
        "server.rack" to Icons.Rounded.Dns,
        "rectangle" to Icons.Rounded.StarBorder,
        "fish" to Icons.Rounded.WaterDrop,
        "cursorarrow.click.2" to Icons.Rounded.Mouse,
        "keyboard" to Icons.Rounded.Keyboard,
        "waveform.path" to Icons.Rounded.GraphicEq,
        "drop" to Icons.Rounded.WaterDrop,
        "network" to Icons.Rounded.AccountTree,
        "memorychip" to Icons.Rounded.Memory,
        "sun.max" to Icons.Rounded.WbSunny,
        "atom" to Icons.Rounded.Science,
        "mountain.2" to Icons.Rounded.Landscape,
        "sun.dust" to Icons.Rounded.Flare,
        "hare" to Icons.Rounded.Speed,
        "xmark.circle" to Icons.Rounded.Cancel,
        "checkmark.circle" to Icons.Rounded.CheckCircle,
        "checkmark.circle.fill" to Icons.Rounded.CheckCircle,
        "xmark.circle.fill" to Icons.Rounded.Cancel,
        "arrow.up.forward.circle" to Icons.Rounded.NorthEast,
        "arrow.up.circle" to Icons.Rounded.ArrowCircleUp,
        "pause.circle" to Icons.Rounded.PauseCircle,
        "info.circle" to Icons.Rounded.Info,
        "bitcoinsign.circle" to Icons.Rounded.MonetizationOn,
        "dollarsign.circle" to Icons.Rounded.MonetizationOn,
        "figure.run.circle" to Icons.AutoMirrored.Rounded.DirectionsRun,
        "arrow.left.arrow.right.circle" to Icons.Rounded.SwapHoriz,
        "circle.hexagongrid.circle" to Icons.Rounded.Widgets,
        "cpu" to Icons.Rounded.Memory,
        "dollarsign.arrow.circlepath" to Icons.Rounded.Casino,
        "square.stack.3d.down.forward" to Icons.Rounded.Layers,
        "arrow.turn.up.right" to Icons.Rounded.NorthEast,
        "arrow.up.right" to Icons.Rounded.NorthEast,
        "square.grid.3x2" to Icons.Rounded.GridView,
        "airplane.departure" to Icons.Rounded.FlightTakeoff,
        "hammer" to Icons.Rounded.Gavel,
        "suit.diamond" to Icons.Rounded.Style,
        "suit.heart" to Icons.Rounded.Favorite,
        "suit.club" to Icons.Rounded.Style,
        "scope" to Icons.Rounded.GpsFixed,
        "arrow.turn.down.right" to Icons.Rounded.ChevronRight,
        "newspaper" to Icons.Rounded.Description,
        )
    }

    /**
     * The icon for a symbol: its exact name, else without ".fill", else without ".circle" too
     * (so "plus.circle.fill" finds "plus.circle", and "bolt.fill" finds "bolt").
     */
    fun icon(sfSymbol: String): ImageVector {
        val plain = sfSymbol.removeSuffix(".fill")
        return table[sfSymbol] ?: table[plain] ?: table[plain.removeSuffix(".circle")] ?: Icons.Rounded.AutoAwesome
    }
}
