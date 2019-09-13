import { Dimensions } from 'react-native';

const { width, height } = Dimensions.get('window');
let calRatio = width <= height ? 16 * (width / height) : 16 * (height / width);
if (width <= height) {
  if (calRatio < 9) {
    calRatio = width / 9;
  } else {
    calRatio = height / 18;
  }
} else {
  if (calRatio < 9) {
    calRatio = height / 9;
  } else {
    calRatio = width / 18;
  }
}

export const screenWidth = width;
export const screenHeight = height;
export const ratio = calRatio / (360 / 9);
