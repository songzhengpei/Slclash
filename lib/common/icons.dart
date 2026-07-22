import 'package:fl_clash/enum/enum.dart';
import 'package:flutter/material.dart';

/// Standard visual sizes for the app icon system.
abstract final class SurgeIconSize {
  static const double inline = 16;
  static const double compact = 18;
  static const double regular = 20;
  static const double navigation = 24;
}

/// Semantic Material Rounded icons used by the FlClash UI.
///
/// UI code must use this dictionary instead of selecting [Icons] directly.
abstract final class SurgeIcons {
  // Navigation
  static const dashboard = Icons.space_dashboard_rounded;
  static const proxies = Icons.article_rounded;
  static const profiles = Icons.folder_rounded;
  static const requests = Icons.view_timeline_rounded;
  static const connections = Icons.lan_rounded;
  static const resources = Icons.storage_rounded;
  static const logs = Icons.article_rounded;
  static const tools = Icons.construction_rounded;
  static const fallback = Icons.circle_rounded;

  // Navigation — filled variants (selected state / original style)
  static const dashboardFilled = Icons.space_dashboard;
  static const proxiesFilled = Icons.article;
  static const profilesFilled = Icons.folder;
  static const toolsFilled = Icons.construction;

  // Navigation — outlined variants (unselected state)
  static const dashboardOutlined = Icons.space_dashboard_outlined;
  static const proxiesOutlined = Icons.article_outlined;
  static const profilesOutlined = Icons.folder_outlined;
  static const toolsOutlined = Icons.construction_outlined;

  static (IconData selected, IconData unselected) bottomNavigationPair(
    PageLabel pageLabel,
  ) {
    return switch (pageLabel) {
      PageLabel.dashboard => (dashboardFilled, dashboardOutlined),
      PageLabel.proxies => (proxiesFilled, proxiesOutlined),
      PageLabel.profiles => (profilesFilled, profilesOutlined),
      PageLabel.tools => (toolsFilled, toolsOutlined),
      _ => (fallback, fallback),
    };
  }

  static IconData bottomNavigation(PageLabel pageLabel) {
    return switch (pageLabel) {
      PageLabel.dashboard => dashboard,
      PageLabel.proxies => proxies,
      PageLabel.profiles => profiles,
      PageLabel.tools => tools,
      _ => fallback,
    };
  }

  // Common actions
  static const add = Icons.add_rounded;
  static const remove = Icons.remove_rounded;
  static const close = Icons.close_rounded;
  static const back = Icons.arrow_back_rounded;
  static const forward = Icons.arrow_forward_ios_rounded;
  static const arrowUp = Icons.arrow_upward_rounded;
  static const arrowDown = Icons.arrow_downward_rounded;
  static const chevronRight = Icons.chevron_right_rounded;
  static const expand = Icons.expand_more_rounded;
  static const collapse = Icons.keyboard_arrow_up_rounded;
  static const down = Icons.keyboard_arrow_down_rounded;
  static const search = Icons.search_rounded;
  static const menu = Icons.menu_rounded;
  static const more = Icons.more_horiz_rounded;
  static const moreVertical = Icons.more_vert_rounded;
  static const confirm = Icons.check_rounded;
  static const selectAll = Icons.select_all_rounded;
  static const deselect = Icons.deselect_rounded;
  static const save = Icons.save_rounded;
  static const copy = Icons.content_copy_rounded;
  static const paste = Icons.paste_rounded;
  static const edit = Icons.edit_rounded;
  static const editFilled = Icons.edit;
  static const delete = Icons.delete_rounded;
  static const deleteAll = Icons.delete_sweep_rounded;
  static const refresh = Icons.refresh_rounded;
  static const replay = Icons.replay_rounded;
  static const sync = Icons.sync_rounded;
  static const cloudSync = Icons.cloud_sync_rounded;
  static const providerDownload = Icons.cloud_download_outlined;
  static const download = Icons.download_rounded;
  static const upload = Icons.upload_rounded;
  static const uploadFile = Icons.upload_file_rounded;
  static const share = Icons.ios_share_rounded;
  static const openInNew = Icons.open_in_new_rounded;
  static const filter = Icons.filter_alt_rounded;
  static const tune = Icons.tune_rounded;
  static const sort = Icons.sort_rounded;
  static const sortAlphabetically = Icons.sort_by_alpha_rounded;
  static const undo = Icons.undo_rounded;
  static const redo = Icons.redo_rounded;
  static const dragHandle = Icons.drag_handle_rounded;
  static const play = Icons.play_arrow_rounded;
  static const pause = Icons.pause_circle_outline_rounded;
  static const stop = Icons.stop_rounded;
  static const visibility = Icons.visibility_rounded;
  static const visibilityFilled = Icons.visibility;
  static const visibilityOff = Icons.visibility_off_rounded;

  // Status and feedback
  static const info = Icons.info_rounded;
  static const error = Icons.error_rounded;
  static const warning = Icons.report_problem_rounded;
  static const success = Icons.check_circle_rounded;
  static const successOutline = Icons.check_circle_outline_rounded;
  static const verified = Icons.verified_rounded;
  static const newRelease = Icons.new_releases_rounded;
  static const loading = Icons.auto_mode_rounded;

  // Network and proxy
  static const proxyGroup = Icons.account_tree_rounded;
  static const selector = Icons.adjust_rounded;
  static const route = Icons.route_rounded;
  static const rule = Icons.rule_rounded;
  static const network = Icons.public_rounded;
  static const networkCheck = Icons.network_check_rounded;
  static const networkPing = Icons.network_ping_rounded;
  static const speed = Icons.speed_rounded;
  static const traffic = Icons.data_saver_off_rounded;
  static const outboundMode = Icons.call_split_rounded;
  static const dns = Icons.dns_rounded;
  static const vpn = Icons.vpn_lock_rounded;
  static const vpnKey = Icons.vpn_key_rounded;
  static const connection = Icons.devices_rounded;
  static const localNetwork = Icons.device_hub_rounded;
  static const hub = Icons.hub_rounded;
  static const block = Icons.block_rounded;
  static const target = Icons.gps_fixed_rounded;

  // Settings and data
  static const account = Icons.account_circle_rounded;
  static const accountBox = Icons.account_box_rounded;
  static const api = Icons.api_rounded;
  static const appearance = Icons.palette_rounded;
  static const colorize = Icons.colorize_rounded;
  static const contrast = Icons.contrast_rounded;
  static const blur = Icons.blur_on_rounded;
  static const themeLight = Icons.light_mode_rounded;
  static const themeDark = Icons.dark_mode_rounded;
  static const language = Icons.language_rounded;
  static const keyboard = Icons.keyboard_rounded;
  static const computer = Icons.computer_rounded;
  static const memory = Icons.memory_rounded;
  static const storage = Icons.storage_rounded;
  static const library = Icons.library_books_rounded;
  static const list = Icons.view_list_rounded;
  static const timeline = Icons.timeline_rounded;
  static const schedule = Icons.schedule_rounded;
  static const timer = Icons.timer_rounded;
  static const settings = Icons.settings_rounded;
  static const build = Icons.build_rounded;
  static const developer = Icons.developer_board_rounded;
  static const code = Icons.code_rounded;
  static const codeOff = Icons.code_off_rounded;
  static const compress = Icons.compress_rounded;
  static const polymer = Icons.polymer_rounded;
  static const doubleArrow = Icons.double_arrow_rounded;
  static const water = Icons.water_drop_rounded;
  static const map = Icons.map_rounded;
  static const explore = Icons.travel_explore_rounded;
  static const update = Icons.update_rounded;
  static const systemUpdate = Icons.system_update_alt_rounded;
  static const password = Icons.password_rounded;
  static const lock = Icons.lock_rounded;

  // Lists, cards, and profile configuration
  static const apps = Icons.apps_rounded;
  static const agenda = Icons.view_agenda_rounded;
  static const alignLeft = Icons.format_align_left_rounded;
  static const dashboardCustomize = Icons.dashboard_customize_rounded;
  static const stars = Icons.stars_rounded;
  static const rocket = Icons.rocket_rounded;
  static const autoAwesome = Icons.auto_awesome_rounded;
  static const style = Icons.style_rounded;
  static const swap = Icons.swap_horiz_rounded;
  static const emergency = Icons.emergency_rounded;
  static const link = Icons.link_rounded;
  static const verticalAlignTop = Icons.vertical_align_top_rounded;

  // Scanner and media checks
  static const camera = Icons.photo_camera_back_rounded;
  static const flashAuto = Icons.flash_auto_rounded;
  static const flashOn = Icons.flash_on_rounded;
  static const flashOff = Icons.flash_off_rounded;
  static const monitorHealth = Icons.monitor_heart_rounded;
  static const mediaCheck = Icons.fact_check_rounded;
  static const gpt = Icons.psychology_alt_rounded;
  static const youtube = Icons.smart_display_rounded;
  static const health = Icons.eco_rounded;
  static const wifiDisabled = Icons.wifi_tethering_off_rounded;
}
