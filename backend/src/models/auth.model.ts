import type { UserResponse } from "./user.model.js";

export interface LoginResponse {
  accessToken: string;
  tokenType: "Bearer";
  expiresIn: string;
  user: UserResponse;
}
