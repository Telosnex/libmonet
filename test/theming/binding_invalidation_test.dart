import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/libmonet.dart';
import 'package:libmonet/theming/paint/palette_motion.dart'
    show PaintMotionStats;

const duration = Duration(milliseconds: 160);
MonetThemeData theme(Color color) => MonetThemeData.fromColors(
  brightness: Brightness.light,
  primary: color,
  secondary: Colors.teal,
  tertiary: Colors.orange,
  backgroundTone: 94,
);
Palette flat(Color color) => ResolvedPalette([
  for (final role in PaletteRole.values)
    role == PaletteRole.background ? Colors.white : color,
], ColorModel.kDefault);

void main() {
  test(
    'coordinator emits lifecycle only while bindings receive lazy ticks',
    () {
      final stats = PaintMotionStats();
      final bus = MonetPaintColors(theme(Colors.red), stats: stats);
      addTearDown(bus.dispose);
      expect(bus.value.primary.color, Colors.red); // Inherited demand too.
      final binding = bus.bindThemePalette(
        MonetPalette.primary,
        roles: {PaletteRole.color},
      );
      var calls = 0, paintCalls = 0;
      bus.addListener(() => calls++);
      binding.addListener(() => paintCalls++);
      bus.retarget(theme(Colors.blue), time: 0, duration: duration);
      final start = calls, paintStart = paintCalls, reads = stats.roleReads;
      for (var i = 1; i <= 10; i++) {
        final before = stats.interpolations;
        bus.sample(i * .008);
        expect(
          calls - start,
          0,
          reason: 'paint ticks must not fan out to scope listeners',
        );
        expect(paintCalls - paintStart, i);
        expect(
          stats.interpolations,
          before,
          reason: 'notification must not calculate RGB',
        );
        expect(
          stats.roleReads,
          reads,
          reason: 'notification must not solve endpoints',
        );
        final color = bus.value.primary.color;
        expect(color, isNot(Colors.red));
        expect(color, isNot(Colors.blue));
        expect(stats.interpolations, before + 1);
        bus.sample(i * .008);
        expect(paintCalls - paintStart, i, reason: 'same timestamp is inert');
      }
      bus.sample(2);
      expect(
        calls - start,
        1,
        reason: 'the coordinator reports semantic completion',
      );
      expect(paintCalls - paintStart, 11);
      expect(bus.value.primary.color, Colors.blue);
      bus.sample(3);
      expect(
        calls - start,
        1,
        reason: 'completion stops notifications without reads',
      );
    },
  );

  test('implicit bus demand neither broadcasts locally nor interpolates unread roles', () {
    final stats = PaintMotionStats();
    final bus = MonetPaintColors(theme(Colors.red), stats: stats);
    addTearDown(bus.dispose);
    expect(bus.value.primary.color, Colors.red);
    final static = bus.bindThemePalette(
      MonetPalette.secondary,
      roles: {PaletteRole.color},
    );
    var localCalls = 0, busCalls = 0;
    static.addListener(() => localCalls++);
    bus.addListener(() => busCalls++);
    bus.retarget(theme(Colors.blue), time: 0, duration: duration);
    final start = busCalls, reads = stats.roleReads;
    for (var i = 1; i <= 10; i++) {
      bus.sample(i * .008);
    }
    expect(
      busCalls - start,
      0,
      reason: 'inherited demand does not opt into a broad paint subscription',
    );
    expect(localCalls, 0);
    expect(stats.interpolations, 0);
    expect(stats.roleReads, reads);
    // Disabling inherited demand releases that subscription, not the binding.
    bus.retarget(
      theme(Colors.red),
      time: .08,
      duration: duration,
      animateUnboundRoles: false,
    );
    final disabledCalls = busCalls;
    bus.sample(.1);
    expect(busCalls, disabledCalls);
    expect(localCalls, 0);
    expect(bus.retainedRoleCount, 1);
  });

  test(
    '1000 static consumers receive no local invalidations or tick RGB work',
    () {
      final stats = PaintMotionStats();
      final bus = MonetPaintColors(
        theme(Colors.red),
        duration: duration,
        stats: stats,
      );
      addTearDown(bus.dispose);
      final static = [
        for (var i = 0; i < 1000; i++)
          bus.bind(
            'static',
            (_) => flat(Colors.grey),
            roles: {PaletteRole.color},
          ),
      ];
      var staticCalls = 0, movingCalls = 0, globalCalls = 0;
      for (final binding in static) {
        binding.addListener(() => staticCalls++);
      }
      final moving = bus.bind(
        'red',
        (_) => flat(Colors.red),
        roles: {PaletteRole.color},
      );
      moving.addListener(() => movingCalls++);
      bus.addListener(() => globalCalls++);
      moving.update('blue', (_) => flat(Colors.blue));
      expect(movingCalls, 0, reason: 'lifecycle cannot notify synchronously');
      final solves = stats.roleReads;
      for (var i = 1; i <= 10; i++) {
        bus.sample(i * .008);
      }
      expect(staticCalls, 0);
      expect(movingCalls, 10);
      expect(
        globalCalls,
        0,
        reason: 'custom paint updates have no scope-wide channel',
      );
      expect(stats.bindingNotifications, 10);
      expect(stats.interpolations, 0);
      expect(stats.roleReads, solves);
      final color = moving.value.color;
      expect(stats.interpolations, 1);
      expect(color, isNot(Colors.red));
      expect(color, isNot(Colors.blue));
      bus.sample(2);
      expect(movingCalls, 11);
      expect(
        globalCalls,
        0,
        reason: 'local completion is not theme completion',
      );
      expect(moving.value.color, Colors.blue);
      bus.sample(3);
      expect(movingCalls, 11);
      for (final b in static) {
        b.dispose();
      }
      moving.dispose();
      expect(bus.retainedRecipeCount, 0);
      expect(bus.retainedRoleCount, 0);
    },
  );

  test(
    'same palette: static roles stay quiet, skipped state reads stay lazy',
    () {
      final stats = PaintMotionStats();
      final first = theme(Colors.red).copyWith(primary: flat(Colors.red));
      final bus = MonetPaintColors(first, stats: stats);
      addTearDown(bus.dispose);
      final background = bus.bindThemePalette(
        MonetPalette.primary,
        roles: {PaletteRole.background},
      );
      final all = bus.bindThemePalette(
        MonetPalette.primary,
        roles: PaletteRole.values.toSet(),
      );
      var staticCalls = 0, calls = 0;
      background.addListener(() => staticCalls++);
      all.addListener(() => calls++);
      bus.retarget(
        first.copyWith(primary: flat(Colors.blue)),
        time: 0,
        duration: duration,
      );
      expect(staticCalls, 0);
      final start = calls, reads = stats.roleReads;
      for (var i = 1; i <= 20; i++) {
        bus.sample(i * .008);
        all.value.color; // dormant hover/pressed roles are NOT interpolated
      }
      expect(calls - start, 20);
      expect(staticCalls, 0);
      expect(stats.interpolations, 20);
      expect(stats.roleReads, reads);
      bus.sample(.16);
      expect(calls - start, 20);
      all.dispose();
      background.dispose();
    },
  );

  test('typed recipes inherit policy, share endpoints across forks, and release keys', () {
    final stats = PaintMotionStats();
    final bus = MonetPaintColors(
      theme(Colors.red),
      stats: stats,
      duration: duration,
    );
    addTearDown(bus.dispose);
    const red = ColorPaletteRecipe(Colors.red);
    const blue = ColorPaletteRecipe(Colors.blue);
    final a = bus.bindRecipe(red, roles: {PaletteRole.color});
    final b = bus.bindRecipe(blue, roles: {PaletteRole.color});
    final before = stats.roleReads;
    a.updateRecipe(blue);
    expect(
      stats.roleReads,
      before,
      reason: 'new trajectory reuses the destination endpoint',
    );
    expect(bus.retainedRecipeCount, 1);
    expect(bus.retainedPaletteCount, 2);
    expect(a.value.color, Colors.red);
    expect(b.value.color, Colors.blue);
    bus.sample(.05);
    expect(a.value.color, isNot(b.value.color));
    bus.sample(2);
    expect(a.value, b.value);
    expect(bus.retainedPaletteCount, 1);
    a.dispose();
    b.dispose();
    expect(bus.retainedRecipeCount, 0);
    for (var i = 0; i < 1000; i++) {
      bus.bindRecipe(ColorPaletteRecipe(Color(0xff123456 + i))).dispose();
    }
    expect(bus.retainedRecipeCount, 0);
    expect(bus.retainedPaletteCount, 0);
    final data = theme(
      Colors.red,
    ).copyWith(algo: Algo.wcag21, contrast: .8, colorModel: ColorModel.oklch);
    final endpoint = red.resolve(data);
    expect(
      endpoint,
      Palette.from(
        Colors.red,
        backgroundTone: data.backgroundTone,
        contrast: data.contrast,
        algo: data.algo,
        colorModel: data.colorModel,
      ),
    );
    const explicit = ColorPaletteRecipe(
      Colors.red,
      background: Colors.indigo,
      contrast: .2,
      algo: Algo.apca,
      colorModel: ColorModel.cam16,
    );
    expect(
      explicit.resolve(data),
      Palette.fromColorAndBackground(
        Colors.red,
        Colors.indigo,
        contrast: .2,
        algo: Algo.apca,
        colorModel: ColorModel.cam16,
      ),
    );
  });

  test(
    'each recipe resolves once per endpoint even with several moving histories',
    () {
      final bus = MonetPaintColors(theme(Colors.red), duration: duration);
      addTearDown(bus.dispose);
      var solves = 0;
      Palette blue(MonetThemeData data) {
        solves++;
        return Palette.from(Colors.blue, backgroundTone: data.backgroundTone);
      }

      final a = bus.bind(
        'red',
        (_) => flat(Colors.red),
        roles: {PaletteRole.color},
      );
      final b = bus.bind(
        'green',
        (_) => flat(Colors.green),
        roles: {PaletteRole.color},
      );
      final c = bus.bind('blue', blue, roles: {PaletteRole.color});
      a.update('blue', blue);
      b.update('blue', blue);
      expect(solves, 1);
      expect(bus.retainedPaletteCount, 3);
      bus.retarget(theme(Colors.orange), time: 0, duration: duration);
      expect(solves, 2);
      bus.sample(.1);
      expect(solves, 2);
      expect(a.value.color, isNot(b.value.color));
      bus.sample(2);
      expect(bus.retainedPaletteCount, 1);
      a.dispose();
      b.dispose();
      c.dispose();
    },
  );

  test('state prewarming is explicit, getter-safe, and ownership survives listener removal', () {
    final stats = PaintMotionStats();
    final bus = MonetPaintColors(
      theme(Colors.red),
      duration: duration,
      stats: stats,
    );
    addTearDown(bus.dispose);
    final binding = bus.bindThemePalette(MonetPalette.primary);
    var notifications = 0;
    void listen() => notifications++;
    binding.addListener(listen);
    binding.prewarm(PaletteStates.fill);
    expect(notifications, 0);
    expect(bus.retainedRoleCount, PaletteStates.fill.length);
    final old = binding.value.fillHovered;
    bus.retarget(theme(Colors.blue), time: 0, duration: duration);
    binding.removeListener(listen);
    final reads = stats.roleReads;
    bus.sample(.05);
    expect(stats.interpolations, 0);
    final current = binding.value.fillHovered;
    expect(current, isNot(old));
    expect(current, isNot(bus.target.primary.fillHovered));
    expect(stats.roleReads, reads);
    expect(bus.retainedRoleCount, PaletteStates.fill.length);
    binding.dispose();
    expect(bus.retainedRoleCount, 0);
  });

  test(
    'deferred invalidation tolerates other-binding disposal and bus teardown',
    () {
      final bus = MonetPaintColors(theme(Colors.red), duration: duration);
      final a = bus.bindThemePalette(
        MonetPalette.primary,
        roles: {PaletteRole.color},
      );
      final b = bus.bindThemePalette(
        MonetPalette.primary,
        roles: {PaletteRole.color},
      );
      var bCalls = 0;
      a.addListener(b.dispose);
      b.addListener(() => bCalls++);
      bus.retarget(theme(Colors.blue), time: 0, duration: duration);
      expect(bCalls, 0);
      final saved = a.value;
      bus.dispose();
      a.dispose();
      b.dispose();
      expect(saved.text, isA<Color>());
    },
  );

  testWidgets(
    'binding notifications repaint only their boundary, without layout/build',
    (tester) async {
      final bus = MonetPaintColors(theme(Colors.red), duration: duration);
      addTearDown(bus.dispose);
      final moving = bus.bindRecipe(const ColorPaletteRecipe(Colors.red));
      final still = bus.bindRecipe(const ColorPaletteRecipe(Colors.grey));
      var paints = 0, staticPaints = 0, layouts = 0, builds = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (_) {
              builds++;
              return Row(
                children: [
                  RepaintBoundary(
                    child: _LayoutCounter(
                      onLayout: () => layouts++,
                      child: CustomPaint(
                        size: const Size(40, 40),
                        painter: _Painter(moving, () => paints++),
                      ),
                    ),
                  ),
                  RepaintBoundary(
                    child: CustomPaint(
                      size: const Size(40, 40),
                      painter: _Painter(still, () => staticPaints++),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
      final layoutCount = layouts,
          paintCount = paints,
          staticCount = staticPaints;
      moving.updateRecipe(const ColorPaletteRecipe(Colors.blue));
      for (var i = 1; i <= 5; i++) {
        bus.sample(i * .02);
        await tester.pump();
      }
      expect(paints, paintCount + 5);
      expect(staticPaints, staticCount);
      expect(layouts, layoutCount);
      expect(builds, 1);
      await tester.pumpWidget(const SizedBox());
      moving.dispose();
      still.dispose();
    },
  );
}

class _Painter extends CustomPainter {
  _Painter(this.binding, this.onPaint) : super(repaint: binding);
  final MonetPaletteBinding binding;
  final VoidCallback onPaint;
  @override
  void paint(Canvas canvas, Size size) {
    onPaint();
    canvas.drawRect(Offset.zero & size, Paint()..color = binding.value.color);
  }

  @override
  bool shouldRepaint(covariant _Painter oldDelegate) =>
      oldDelegate.binding != binding;
}

class _LayoutCounter extends SingleChildRenderObjectWidget {
  const _LayoutCounter({required this.onLayout, required super.child});
  final VoidCallback onLayout;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _CounterRender(onLayout);
}

class _CounterRender extends RenderProxyBox {
  _CounterRender(this.onLayout);
  final VoidCallback onLayout;
  @override
  void performLayout() {
    onLayout();
    super.performLayout();
  }
}
