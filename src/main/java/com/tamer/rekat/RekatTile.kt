package com.tamer.rekat

import androidx.wear.protolayout.ActionBuilders
import androidx.wear.protolayout.ColorBuilders.argb
import androidx.wear.protolayout.DimensionBuilders.dp
import androidx.wear.protolayout.DimensionBuilders.sp
import androidx.wear.protolayout.LayoutElementBuilders
import androidx.wear.protolayout.ModifiersBuilders
import androidx.wear.protolayout.ResourceBuilders
import androidx.wear.protolayout.TimelineBuilders
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.TileService
import com.google.common.util.concurrent.Futures

// Kutucuk: yeşil yuvarlak "Rekat Sayacı" düğmesi, dokununca uygulamayı açar.
class RekatTile : TileService() {
    override fun onTileRequest(req: RequestBuilders.TileRequest) = Futures.immediateFuture(
        TileBuilders.Tile.Builder()
            .setResourcesVersion("1")
            .setTileTimeline(TimelineBuilders.Timeline.fromLayoutElement(dugme()))
            .build()
    )

    override fun onTileResourcesRequest(req: RequestBuilders.ResourcesRequest) =
        Futures.immediateFuture(ResourceBuilders.Resources.Builder().setVersion("1").build())

    private fun dugme(): LayoutElementBuilders.LayoutElement {
        val ac = ActionBuilders.LaunchAction.Builder().setAndroidActivity(
            ActionBuilders.AndroidActivity.Builder()
                .setPackageName(packageName)
                .setClassName(MainActivity::class.java.name).build()
        ).build()
        val yazi = LayoutElementBuilders.Text.Builder()
            .setText(getString(R.string.tile))
            .setMaxLines(2)
            .setMultilineAlignment(LayoutElementBuilders.TEXT_ALIGN_CENTER)
            .setFontStyle(
                LayoutElementBuilders.FontStyle.Builder()
                    .setSize(sp(20f)).setColor(argb(0xFFFFFFFF.toInt()))
                    .setWeight(LayoutElementBuilders.FONT_WEIGHT_BOLD).build()
            ).build()
        return LayoutElementBuilders.Box.Builder()
            .setWidth(dp(150f)).setHeight(dp(150f))
            .setModifiers(
                ModifiersBuilders.Modifiers.Builder()
                    .setClickable(ModifiersBuilders.Clickable.Builder().setId("ac").setOnClick(ac).build())
                    .setBackground(
                        ModifiersBuilders.Background.Builder()
                            .setColor(argb(0xFF0E5A3A.toInt()))
                            .setCorner(ModifiersBuilders.Corner.Builder().setRadius(dp(75f)).build())
                            .build()
                    ).build()
            )
            .addContent(yazi)
            .build()
    }
}
