#!/usr/bin/env bash
set -euo pipefail

echo "## Mihomo 内核更新摘要"
echo ""
echo "- 当前 Core：${CURRENT_SHA:-unknown}"
echo "- 最新稳定版：${STABLE_TAG:-unknown} (${STABLE_SHA:-unknown})"
echo "- 与稳定版关系：${REL:-unknown}"
echo "- 最新 Alpha：${ALPHA_SHA:-unknown}"
echo "- 与 Alpha 关系：${REL_ALPHA:-unknown}"
echo ""

case "${ACTION:-}" in
  fail_closed)
    echo "- 状态：已阻塞。Core 历史与稳定版分叉，需要人工审查。"
    ;;
  noop)
    echo "- 状态：无需更新。"
    if [ "${REL:-}" = AHEAD_OF_STABLE ]; then
      echo "- 当前 Core 领先于最新稳定版，已拒绝自动降级。"
    fi
    ;;
  validate_current|upgrade_stable)
    if [ "${VALIDATION_OUTCOME:-skipped}" = success ]; then
      echo "- 验证：通过。"
    else
      echo "- 验证：失败或未完成 (${VALIDATION_OUTCOME:-skipped})，需要修复后重试。"
    fi
    if [ "${ACTION:-}" = validate_current ]; then
      echo "- 未降级、未创建 PR。"
    elif [ "${DRY_RUN:-false}" = true ]; then
      echo "- Dry run：不 push、不创建 PR、不打 tag、不发布。"
    elif [ "${PUBLICATION_OUTCOME:-skipped}" = success ] && [ -n "${PR_NUMBER:-}" ]; then
      echo "- Draft PR：#$PR_NUMBER"
      if [ "${VALIDATION_OUTCOME:-skipped}" != success ] || [ "${REVIEW_OUTCOME:-skipped}" != success ]; then
        echo "- PR 已标记阻塞，修复并重新通过完整验证前禁止合并。"
      else
        echo "- 自动评估：${REVIEW:-unknown}，风险：${REVIEW_RISK:-unknown}"
        echo "- 等待人工审核后合入 beta。"
      fi
    else
      echo "- PR 发布失败或未完成 (${PUBLICATION_OUTCOME:-skipped})，请检查运行日志。"
    fi
    ;;
  *)
    echo "- 状态：检查失败或未完成，请查看运行日志。"
    ;;
esac
echo "- 工作流结果：${JOB_STATUS:-unknown}"
