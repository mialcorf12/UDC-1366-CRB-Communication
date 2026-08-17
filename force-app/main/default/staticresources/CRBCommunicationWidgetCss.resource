/*
 * message-widget styles — self-contained, prefixed with .msgw so nothing leaks
 * into or out of the host page. Ported visuals from the Clinical Messages panel.
 */
.msgw {
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
  width: 536px;
  max-width: 100vw;
  height: 640px;
  max-height: 100vh;
  background: #263238;
  border-radius: 8px;
  overflow: hidden;
  font-family: Roboto, "Helvetica Neue", Arial, sans-serif;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.3);
}
.msgw * {
  box-sizing: border-box;
}

/* header */
.msgw-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 16px;
  color: #fff;
  border-bottom: 1px solid rgba(255, 255, 255, 0.12);
}
.msgw-header-title {
  font-size: 16px;
  font-weight: 500;
}
.msgw-close {
  background: none;
  border: none;
  color: #fff;
  font-size: 22px;
  line-height: 1;
  cursor: pointer;
  padding: 0 4px;
}

/* thread scroller */
.msgw-thread {
  flex: 1 1 auto;
  overflow-y: auto;
  padding: 8px 16px 16px;
  scrollbar-width: none;
}
.msgw-thread::-webkit-scrollbar {
  display: none;
}

.msgw-loading {
  color: rgba(255, 255, 255, 0.7);
  text-align: center;
  padding: 24px;
}

/* rows */
.msgw-row {
  margin-top: 16px;
  color: #fff;
}
.msgw-row--right {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
}

.msgw-head {
  display: flex;
  align-items: flex-start;
}
.msgw-avatar {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: #16aadc;
  color: #fff;
  font-size: 13px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex: 0 0 32px;
}
.msgw-avatar--logo {
  background: #fff var(--crb-logo-url, none) center / 22px no-repeat;
}
.msgw-meta {
  padding: 0 8px;
}
.msgw-name {
  display: flex;
  align-items: center;
  font-size: 14px;
  color: #fff;
}
.msgw-divider {
  width: 1px;
  height: 12px;
  background: rgba(255, 255, 255, 0.4);
  margin: 0 8px;
}
.msgw-role {
  font-size: 11px;
  letter-spacing: 0.5px;
  color: rgba(255, 255, 255, 0.7);
  text-transform: uppercase;
}
.msgw-time {
  font-size: 12px;
  color: rgba(255, 255, 255, 0.7);
  margin-top: 2px;
}
.msgw-time--right {
  padding: 0 8px;
}

/* bubbles */
.msgw-bubble {
  border-radius: 4px;
  padding: 16px;
  width: 320px;
  word-break: break-word;
  white-space: pre-line;
}
.msgw-bubble--left {
  margin-left: 32px;
  background: #eee;
  color: rgba(0, 0, 0, 0.87);
}
.msgw-bubble--right {
  background: rgba(33, 150, 243, 0.16);
  color: #fff;
}
.msgw-subject {
  font-weight: 700;
  font-size: 14px;
  color: #0288d1;
  margin-bottom: 2px;
}
.msgw-bubble--right .msgw-subject {
  color: #4fc3f7;
}
.msgw-title {
  font-weight: 700;
  color: #215ecd;
  margin-bottom: 4px;
}
.msgw-bubble--right .msgw-title {
  color: #4fc3f7;
}
.msgw-text {
  font-size: 14px;
  line-height: 1.4;
}

/* status lines */
.msgw-status {
  display: flex;
  flex-direction: row-reverse;
  align-items: center;
  gap: 6px;
  color: #0288d1;
  font-size: 12px;
  padding-top: 6px;
  margin-left: 32px;
}
.msgw-row--right .msgw-status {
  margin-left: 0;
}
.msgw-status-icon {
  color: rgba(2, 136, 209, 1);
  font-weight: 700;
}

/* action buttons */
.msgw-actions {
  display: flex;
  justify-content: flex-end;
  margin-top: 8px;
  margin-left: 32px;
}
.msgw-btn {
  font-size: 13px;
  font-weight: 500;
  letter-spacing: 0.4px;
  text-transform: uppercase;
  border: none;
  border-radius: 4px;
  padding: 6px 12px;
  cursor: pointer;
}
.msgw-btn--primary {
  background: #0288d1;
  color: #fff;
}
.msgw-btn:disabled {
  background: rgba(255, 255, 255, 0.2);
  color: rgba(255, 255, 255, 0.5);
  cursor: not-allowed;
}

/* banners */
.msgw-banner {
  border-radius: 4px;
  padding: 8px 16px;
  margin-top: 8px;
  font-size: 14px;
}
.msgw-banner--info {
  background: #e5f6fd;
  color: #014361;
}
.msgw-banner--error {
  background: #f44336;
  color: #fff;
}

/* empty state */
.msgw-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
  padding: 32px 16px;
  color: #fff;
}
.msgw-empty-title {
  font-size: 20px;
  font-weight: 500;
  margin-bottom: 10px;
}
.msgw-empty-sub {
  font-size: 14px;
  text-align: center;
  color: rgba(255, 255, 255, 0.8);
  max-width: 320px;
}

/* composer */
.msgw-composer {
  padding: 16px;
  border-top: 1px solid rgba(255, 255, 255, 0.12);
}
.msgw-composer-box {
  display: flex;
  align-items: flex-end;
  gap: 8px;
  background: #fff;
  border: 1px solid transparent;
  border-radius: 4px;
  padding: 8px;
  transition: border-color 0.1s linear;
}
.msgw-composer-box:focus-within {
  border-color: #0288d1;
}
.msgw-input {
  flex: 1 1 auto;
  border: none;
  outline: none;
  resize: none;
  font-family: inherit;
  font-size: 14px;
  line-height: 1.4;
  max-height: 160px;
  color: rgba(0, 0, 0, 0.87);
}
.msgw-input:disabled {
  background: transparent;
  color: rgba(0, 0, 0, 0.38);
}
.msgw-send {
  flex: 0 0 auto;
  background: none;
  border: none;
  color: #0288d1;
  font-size: 18px;
  cursor: pointer;
  padding: 4px;
}
.msgw-send:disabled {
  color: rgba(0, 0, 0, 0.26);
  cursor: not-allowed;
}
