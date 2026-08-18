/*
 * message-widget styles — self-contained, prefixed with .msgw so nothing leaks
 * into or out of the host page. Ported visuals from the Clinical Messages panel.
 */
.msgw {
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
  height: 640px;
  max-height: 100vh;
  background: #fff;
  border: 1px solid #e0e0e0;
  border-radius: 8px;
  overflow: hidden;
  font-family: Roboto, "Helvetica Neue", Arial, sans-serif;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.12);
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
  color: #1a1a1a;
  border-bottom: 1px solid #eee;
}
.msgw-header-title {
  font-size: 16px;
  font-weight: 500;
}
.msgw-close {
  background: none;
  border: none;
  color: #1a1a1a;
  font-size: 22px;
  line-height: 1;
  cursor: pointer;
  padding: 0 4px;
}
.msgw-sync {
    margin-right: 15px !important;
    border-radius: 50px !important;
    background-color: #abe7eb !important;
    color: #111212 !important;
    font-size: 14px !important;
    height: 40px !important;
    padding: 0 25px !important;
    font-family: 'system-ui' !important;
    white-space: nowrap;
    text-align: center;
    font-weight: bold;
    box-shadow: 0 4px 10px rgba(0, 0, 0, 0.1);
    transition: all .3s ease;
    animation: pulse 1.5s infinite;
}

/* thread scroller */
.msgw-thread {
  flex: 1 1 auto;
  overflow-y: auto;
  padding: 8px 16px 16px;
  scrollbar-width: none;
  background: #fff;
}
.msgw-thread::-webkit-scrollbar {
  display: none;
}

.msgw-loading {
  color: rgba(0, 0, 0, 0.6);
  text-align: center;
  padding: 24px;
}

/* rows */
.msgw-row {
  margin-top: 16px;
  color: #1a1a1a;
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
  color: #1a1a1a;
}
.msgw-divider {
  width: 1px;
  height: 12px;
  background: rgba(0, 0, 0, 0.2);
  margin: 0 8px;
}
.msgw-role {
  font-size: 11px;
  letter-spacing: 0.5px;
  color: #5f6368;
  text-transform: uppercase;
}
.msgw-time {
  font-size: 12px;
  color: #5f6368;
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
  background: #eef1f3;
  color: rgba(0, 0, 0, 0.87);
  border-left: 4px solid #0288d1;
  border-radius: 2px 4px 4px 2px;
}
.msgw-bubble--right {
  background: #f1f8ff;
  color: rgba(0, 0, 0, 0.87);
  border: 1px solid #dceafd;
}
.msgw-subject {
  font-weight: 700;
  font-size: 14px;
  color: #0288d1;
  margin-bottom: 2px;
}
.msgw-bubble--right .msgw-subject {
  color: #0d6cb8;
}
.msgw-title {
  font-weight: 700;
  color: #215ecd;
  margin-bottom: 4px;
}
.msgw-bubble--right .msgw-title {
  color: #0d6cb8;
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
  background: #fff;
  color: #0288d1;
  border: 1px solid #0288d1;
  border-radius: 999px;
}
.msgw-btn--primary:hover:not(:disabled) {
  background: rgba(2, 136, 209, 0.08);
}
.msgw-btn:disabled {
  background: #f5f5f5;
  color: rgba(0, 0, 0, 0.26);
  border-color: #e0e0e0;
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
  color: #1a1a1a;
}
.msgw-empty-title {
  font-size: 20px;
  font-weight: 500;
  margin-bottom: 10px;
}
.msgw-empty-sub {
  font-size: 14px;
  text-align: center;
  color: #5f6368;
  max-width: 320px;
}

/* composer */
.msgw-composer {
  padding: 16px;
  border-top: 1px solid #eee;
  background: #fff;
}
.msgw-composer-box {
  display: flex;
  align-items: flex-end;
  gap: 8px;
  background: #f1f3f4;
  border: 1px solid transparent;
  border-radius: 24px;
  padding: 8px 8px 8px 16px;
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
  width: 32px;
  height: 32px;
  background: #0288d1;
  border: none;
  border-radius: 50%;
  color: #fff;
  font-size: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  padding: 0;
}
.msgw-send:disabled {
  background: #e0e0e0;
  color: rgba(0, 0, 0, 0.26);
  cursor: not-allowed;
}
