#!/usr/bin/env bash
# Publish a reviewable proposal even when tool setup or core validation failed.
set -euo pipefail

: "${BRANCH:?}" "${LATEST_TAG:?}" "${LATEST_SHA:?}" "${GITHUB_REPOSITORY:?}"
RUN_URL="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
BODY_FILE="$RUNNER_TEMP/mihomo-update-pr.md"
HEAD_SHA="$(git rev-parse HEAD)"
PINNED_SHA="$(git rev-parse HEAD:core/Clash.Meta)"
if [ "$PINNED_SHA" != "$LATEST_SHA" ]; then
  echo "Refusing to publish: the proposal does not pin the resolved stable SHA." >&2
  exit 1
fi

STATE=failure
CONCLUSION="验证失败或未完成，需要修复后重新验证"
if [ "${VALIDATION_OUTCOME:-skipped}" = success ] && \
   [ "${DEPENDENCIES_OUTCOME:-skipped}" = success ] && \
   [ "${REVIEW_OUTCOME:-skipped}" = success ]; then
  STATE=success
  CONCLUSION="${REVIEW_CONCLUSION:?}"
fi

{
  echo "## Mihomo 内核更新"
  echo ""
  echo "- 当前版本：${CURRENT_TAG:-unknown}（${CURRENT_SHA:-unknown}）"
  echo "- 目标版本：$LATEST_TAG（$LATEST_SHA）"
  echo "- 自动验证：$STATE"
  echo "- 结论：$CONCLUSION"
  echo "- 运行日志：[$GITHUB_RUN_ID]($RUN_URL)"
  echo ""
  echo "本 PR 使用官方稳定版提交，保持 Draft，由人工审核后合入 beta。"
  if [ "$STATE" = success ]; then
    cat "${REVIEW_FILE:?}"
  else
    echo ""
    echo "**当前禁止合并：必须修复问题并重新通过完整验证。**"
    echo ""
    echo "- Go 环境准备：${SETUP_GO_OUTCOME:-skipped}"
    echo "- Java 环境准备：${SETUP_JAVA_OUTCOME:-skipped}"
    echo "- Flutter 环境准备：${SETUP_FLUTTER_OUTCOME:-skipped}"
    echo "- Android NDK 准备：${SETUP_NDK_OUTCOME:-skipped}"
    echo "- Go 依赖整理：${DEPENDENCIES_OUTCOME:-skipped}"
    echo "- 内核兼容性测试及 Android arm64 构建：${VALIDATION_OUTCOME:-skipped}"
    echo "- 升级评估：${REVIEW_OUTCOME:-skipped}"
    LOG_FILE="$RUNNER_TEMP/mihomo-core-validation.log"
    if [ -s "$LOG_FILE" ]; then
      echo ""
      echo "### 验证日志末尾（完整日志见上方链接）"
      echo '````text'
      tail -n 100 "$LOG_FILE"
      echo '````'
    fi
  fi
} > "$BODY_FILE"

git push --force-with-lease origin "$BRANCH"
# Attach the result to the exact proposed commit, including Go dependency
# changes. A bot-created PR need not have run its pull_request workflow yet.
gh api "repos/$GITHUB_REPOSITORY/statuses/$HEAD_SHA" \
  -f "state=$STATE" -f 'context=Mihomo core update validation' \
  -f "target_url=$RUN_URL" -f "description=$CONCLUSION" > /dev/null

PR_NUMBER="$(gh pr list --repo "$GITHUB_REPOSITORY" --head "$BRANCH" --base beta \
  --state open --json number --jq '.[0].number // empty')"
TITLE="Mihomo 内核更新 $LATEST_TAG：$CONCLUSION"
if [ -n "$PR_NUMBER" ]; then
  if [ "$(gh pr view "$PR_NUMBER" --repo "$GITHUB_REPOSITORY" --json isDraft --jq '.isDraft')" != true ]; then
    gh pr ready "$PR_NUMBER" --repo "$GITHUB_REPOSITORY" --undo
  fi
  gh pr edit "$PR_NUMBER" --repo "$GITHUB_REPOSITORY" --title "$TITLE" --body-file "$BODY_FILE"
else
  PR_URL="$(gh pr create --repo "$GITHUB_REPOSITORY" --draft --base beta \
    --head "$BRANCH" --title "$TITLE" --body-file "$BODY_FILE")"
  PR_NUMBER="${PR_URL##*/}"
fi
echo "pr_number=$PR_NUMBER" >> "$GITHUB_OUTPUT"
echo "PR #$PR_NUMBER 已创建或更新，验证结果：$STATE"
