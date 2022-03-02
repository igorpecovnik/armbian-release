#!/bin/bash

# Run in build/output dir
MATRIX_BOARD="$1"
CLOUD_IMAGE="${CLOUD_IMAGE:-yes}"
CLOUD_IMAGE_DESC="cli"
[[ "${CLOUD_IMAGE}" == "yes" ]] && CLOUD_IMAGE_DESC="cloud"

echo "Preparing release Markdown fragment for this run..."
cat << EOD > release.md
- \`${MATRIX_BOARD}\`: ${MATRIX_DESC}
EOD

echo "Compressing files..."
find ./images -type f -size +1M | cut -d "/" -f 3 | while read fn; do
	echo "Compressing '$fn'..."

	FULL_SRC_FN="images/${fn}"
	ORIGINAL_SIZE="$(du -h "${FULL_SRC_FN}" | tr -s "\t" " " | cut -d " " -f 1)"
	UNSPARSE_SIZE="$(du --apparent-size -h "${FULL_SRC_FN}" | tr -s "\t" " " | cut -d " " -f 1)"
	TARGET_FN="${fn}.zst"
	FULL_TARGET_FN="images/${fn}.zst"

	SPARSE=""
	if [[ "${ORIGINAL_SIZE}" != "${UNSPARSE_SIZE}" ]]; then
		SPARSE=", sparse:${UNSPARSE_SIZE}b"
	fi

	echo "Compressing ${FULL_SRC_FN} to ${FULL_TARGET_FN}"
	time zstd -T0 -4 --rm -o "${FULL_TARGET_FN}" "${FULL_SRC_FN}"
	ZST_SIZE="$(du -h "${FULL_TARGET_FN}" | tr -s "\t" " " | cut -d " " -f 1)"

	echo "  - [${TARGET_FN}](https://github.com/${RELEASE_OWNER_AND_REPO}/releases/download/${RELEASE_TAG}/${TARGET_FN}) _(zst:${ZST_SIZE}b, original:${ORIGINAL_SIZE}b${SPARSE})_" >> release.md
done

echo "Listing images contents:"
ls -laht ./images || true

# GH Releases/packages has a limit of 2Gb per artifact.
# For not just remove, @TODO: in the future could split.
echo "Removing too-big images: "
find ./images -type f -size +2G || true
find ./images -type f -size +2G -exec rm -f {} ";" || true

# Tar up the logs # @TODO: armbian-next changed this. the logs will end up in "output/logs", not debug. eventually.
LOGS_TARBALL="images/build.logs.${MATRIX_BOARD}.${CLOUD_IMAGE_DESC}.tar"
echo "Tarring up the build logs... ${LOGS_TARBALL}.zst"
tar cf "${LOGS_TARBALL}" logs || true
zstd -T0 -4 --rm -o "${LOGS_TARBALL}.zst" "${LOGS_TARBALL}" || true

echo "Chown images back to regular user (${REGULAR_USER})..."
chown -R "${REGULAR_USER}":"${REGULAR_USER}" ./images || true
