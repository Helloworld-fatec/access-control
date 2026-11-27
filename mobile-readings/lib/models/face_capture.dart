const maxFaceCaptures = 3;
const maxFacePhotoBytes = 102400;

bool isSupportedFaceJpeg(List<int> bytes) =>
    bytes.length >= 3 &&
    bytes.length <= maxFacePhotoBytes &&
    bytes[0] == 0xff &&
    bytes[1] == 0xd8 &&
    bytes[2] == 0xff;
