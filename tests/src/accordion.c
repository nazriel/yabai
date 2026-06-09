TEST_FUNC(horizontal_accordion_area,
{
    struct area base;
    base.x = 0;
    base.y = 0;
    base.w = 100;
    base.h = 50;

    struct area prev = area_apply_accordion(VIEW_HORIZONTAL_ACCORDION, 10, base, 3, 0, 1);
    TEST_CHECK((int) prev.x, 0);
    TEST_CHECK((int) prev.w, 90);

    struct area active = area_apply_accordion(VIEW_HORIZONTAL_ACCORDION, 10, base, 3, 1, 1);
    TEST_CHECK((int) active.x, 10);
    TEST_CHECK((int) active.w, 80);

    struct area next = area_apply_accordion(VIEW_HORIZONTAL_ACCORDION, 10, base, 3, 2, 1);
    TEST_CHECK((int) next.x, 10);
    TEST_CHECK((int) next.w, 90);
});

TEST_FUNC(vertical_accordion_area,
{
    struct area base;
    base.x = 0;
    base.y = 0;
    base.w = 100;
    base.h = 50;

    struct area active = area_apply_accordion(VIEW_VERTICAL_ACCORDION, 10, base, 3, 1, 1);
    TEST_CHECK((int) active.y, 10);
    TEST_CHECK((int) active.h, 30);
});

TEST_FUNC(accordion_area_edges_and_clamp,
{
    struct area base;
    base.x = 0;
    base.y = 0;
    base.w = 100;
    base.h = 50;

    struct area first = area_apply_accordion(VIEW_HORIZONTAL_ACCORDION, 10, base, 3, 0, 0);
    TEST_CHECK((int) first.x, 0);
    TEST_CHECK((int) first.w, 90);

    struct area last = area_apply_accordion(VIEW_HORIZONTAL_ACCORDION, 10, base, 3, 2, 2);
    TEST_CHECK((int) last.x, 10);
    TEST_CHECK((int) last.w, 90);

    struct area small;
    small.x = 0;
    small.y = 0;
    small.w = 15;
    small.h = 50;
    struct area clamped = area_apply_accordion(VIEW_HORIZONTAL_ACCORDION, 10, small, 3, 1, 1);
    TEST_CHECK((int) clamped.x, 7);
    TEST_CHECK((int) clamped.w, 1);
});
