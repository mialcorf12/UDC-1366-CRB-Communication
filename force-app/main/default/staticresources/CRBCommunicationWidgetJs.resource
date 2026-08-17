/* eslint-disable */
/**
 * message-widget — hosted, framework-agnostic build of the Clinical "Messages"
 * panel (ported from src/modules/Clinical/components/SideBar/message.tsx).
 *
 * This file is served from the Go API at /message-widget/latest/widget.js and
 * mounted by any host (UDC, Salesforce, uFab) via window.MessageWidget.mount().
 * It owns NO auth logic: before every request it calls getToken(); on a 401 it
 * calls getToken(true) once to force a fresh token, and if that still 401s it
 * surfaces { status: 401 } through onError so the host can re-authenticate.
 *
 * Vanilla JS on purpose — no React / MUI / Redux — so the bundle stays portable
 * and small. Do not add build-time dependencies here.
 */
(function () {
  "use strict"

  var VERSION = "0.1.0"

  // ---- case dispositions that unlock the composer / action buttons ---------
  var STATUS = {
    REVIEW_PLAN: "REVIEW_PLAN",
    REVIEW_MODIFICATION: "REVIEW_MODIFICATION",
    SUBMITTED_TO_UASSIST: "SUBMITTED_TO_UASSIST",
    ATTENTION_NEEDED: "ATTENTION_NEEDED",
    PLACE_ORDER: "PLACE_ORDER",
    MODIFICATION_REQUESTED: "MODIFICATION_REQUESTED",
  }
  var INPUT_ENABLED_STATUSES = [
    STATUS.REVIEW_PLAN,
    STATUS.REVIEW_MODIFICATION,
    STATUS.SUBMITTED_TO_UASSIST,
    STATUS.ATTENTION_NEEDED,
    STATUS.PLACE_ORDER,
  ]
  var MODIFICATION_STATUSES = [
    STATUS.REVIEW_PLAN,
    STATUS.REVIEW_MODIFICATION,
    STATUS.PLACE_ORDER,
  ]

  // ---- tiny DOM helpers ----------------------------------------------------
  function el(tag, attrs, children) {
    var node = document.createElement(tag)
    if (attrs) {
      Object.keys(attrs).forEach(function (k) {
        if (k === "class") node.className = attrs[k]
        else if (k === "text") node.textContent = attrs[k]
        else if (k === "html") node.innerHTML = attrs[k]
        else if (k.indexOf("on") === 0 && typeof attrs[k] === "function") {
          node.addEventListener(k.slice(2).toLowerCase(), attrs[k])
        } else if (attrs[k] != null) node.setAttribute(k, attrs[k])
      })
    }
    ;(children || []).forEach(function (c) {
      if (c == null) return
      node.appendChild(typeof c === "string" ? document.createTextNode(c) : c)
    })
    return node
  }

  function pad(n) {
    return n < 10 ? "0" + n : "" + n
  }

  // MM/dd/yy hh:mm a — mirrors dateFormat(time, "MM/dd/yy hh:mm a")
  function formatTime(value) {
    if (!value) return ""
    var d = new Date(value)
    if (isNaN(d.getTime())) return ""
    var h = d.getHours()
    var ampm = h >= 12 ? "PM" : "AM"
    var h12 = h % 12
    if (h12 === 0) h12 = 12
    return (
      pad(d.getMonth() + 1) +
      "/" +
      pad(d.getDate()) +
      "/" +
      String(d.getFullYear()).slice(-2) +
      " " +
      pad(h12) +
      ":" +
      pad(d.getMinutes()) +
      " " +
      ampm
    )
  }

  function initials(lastname, firstname) {
    var l = (lastname || "").charAt(0)
    var f = (firstname || "").charAt(0)
    return (l + f).toUpperCase()
  }

  // ---- authenticated fetch with single 401 -> force-refresh retry ----------
  function createApi(opts) {
    var base = String(opts.apiBaseUrl || "").replace(/\/$/, "")

    function resolveToken(force) {
      return Promise.resolve(opts.getToken ? opts.getToken(force) : null)
    }

    function request(method, path, body) {
      function attempt(force) {
        return resolveToken(force).then(function (token) {
          var headers = { Accept: "application/json" }
          if (token) headers.Authorization = "Bearer " + token
          var init = { method: method, headers: headers }
          if (body !== undefined) {
            headers["Content-Type"] = "application/json"
            init.body = JSON.stringify(body)
          }
          return fetch(base + path, init).then(function (res) {
            if (res.status === 401 && !force) return attempt(true) // one retry
            if (res.status === 401) {
              var err = new Error("Unauthorized")
              err.status = 401
              throw err
            }
            if (!res.ok) {
              var e = new Error("Request failed: " + res.status)
              e.status = res.status
              throw e
            }
            return res.status === 204 ? null : res.json()
          })
        })
      }
      return attempt(false)
    }

    var orgPath =
      "/shared/v1/org/" +
      opts.orgId +
      "/patients/" +
      opts.patientId +
      "/txplans/" +
      opts.caseId
    var orchestrationPath =
      "/shared/v1/org/" +
      opts.orgId +
      "/orchestration/patients/" +
      opts.patientId +
      "/txplans/" +
      opts.caseId
    var casePath =
      "/patient-mgmt/v2/org/" +
      opts.orgId +
      "/patients/" +
      opts.patientId +
      "/txplans/" +
      opts.caseId

    return {
      getMessages: function () {
        return request("GET", orgPath + "/messages")
      },
      getCase: function () {
        return request("GET", casePath)
      },
      markRead: function (messageId) {
        return request("PUT", orgPath + "/messages/" + messageId, { read: 1 })
      },
      postMessage: function (subject, txName, content) {
        return request("POST", orgPath + "/messages", {
          subject: subject,
          txName: txName,
          content: content,
        })
      },
      // is_modification_requested: 1 = modification request, 0 = reply
      postModification: function (txName, content, isModification) {
        var payload =
          isModification === 1
            ? {
                message: content,
                plan_name: txName,
                is_modification_requested: 1,
              }
            : { message: content, is_modification_requested: 0 }
        return request("POST", orchestrationPath + "/messages/", payload)
      },
    }
  }

  // ---- transform raw API results -> flat message rows ----------------------
  function parseBody(body) {
    try {
      return JSON.parse(body) || {}
    } catch (e) {
      return {}
    }
  }

  function mapThread(thread, usersAvatar, isHistory) {
    return (thread || []).map(function (item) {
      var parsed = parseBody(item.body)
      var subject = parsed.subject || ""
      var content = parsed.content || ""
      var firstname = "",
        lastname = "",
        avatarLink = "",
        color = "",
        role = ""

      if (isHistory && parsed.sender) {
        var s = parsed.sender
        firstname = s.firstname || ""
        lastname = s.lastname || ""
        avatarLink = s.avatar_link || ""
        color = s.avatar_color || ""
        role = s.title || ""
      } else if (item.created_by !== 0) {
        var user = (usersAvatar || []).filter(function (u) {
          return u.id === item.created_by
        })[0]
        if (user) {
          firstname = user.first_name || ""
          lastname = user.last_name || ""
          avatarLink = user.avatar_link || ""
          color = user.avatar_color || ""
          role = (user.title_name && user.title_name.type_name) || ""
        }
      }

      return {
        firstname: firstname,
        lastname: lastname,
        time: item.created_at || "",
        photo: avatarLink === "-" ? "" : avatarLink,
        color: color,
        role: (role || "").toUpperCase(),
        messageStatus: item.message_type,
        buttonEnable: item.button_enable,
        message: {
          title: item.plan_name,
          text: content,
          id: item.id,
          subject: subject,
        },
      }
    })
  }

  // ---- widget instance -----------------------------------------------------
  function mount(target, opts) {
    var api = createApi(opts)
    var onError =
      typeof opts.onError === "function" ? opts.onError : function () {}

    var state = {
      messages: [],
      history: [],
      caseDisposition: "",
      selectedPlan: { name: undefined, id: undefined },
      inputValue: "",
      // gate flags — false means "composer open for this action"
      isSubmitModification: true,
      isSubmitReply: true,
      loading: true,
      error: null,
    }

    var root = el("div", { class: "msgw" })
    target.appendChild(root)

    function handleError(err) {
      onError(err)
      if (err && err.status === 401) return // host will re-auth
      state.error = err
      render()
    }

    function refresh() {
      state.loading = true
      render()
      return Promise.all([api.getMessages(), api.getCase().catch(function () {
        return null
      })])
        .then(function (out) {
          var messagesRes = out[0] || {}
          var caseRes = out[1]
          var results = (messagesRes && messagesRes.results) || {}
          state.messages = mapThread(
            results.current_thread,
            results.users_avatar,
            false,
          )
          state.history = mapThread(
            results.previous_thread,
            results.users_avatar,
            true,
          )
          if (caseRes && caseRes.result) {
            state.caseDisposition = caseRes.result.caseDisposition || ""
          }
          state.loading = false
          state.error = null
          render()
          markFirstRead()
          scrollToBottom()
        })
        .catch(function (err) {
          state.loading = false
          handleError(err)
        })
    }

    function markFirstRead() {
      var first = state.messages[0]
      if (!first || !first.message || !first.message.id) return
      api.markRead(first.message.id).catch(function () {
        /* non-fatal */
      })
    }

    function scrollToBottom() {
      var scroller = root.querySelector(".msgw-thread")
      if (scroller) setTimeout(function () {
        scroller.scrollTop = scroller.scrollHeight
      }, 0)
    }

    // ---- send handling: modification -> reply -> plain message -------------
    function send() {
      var content = state.inputValue.trim()
      if (!content) return
      var plan = state.selectedPlan

      var done = function () {
        state.inputValue = ""
        refresh()
      }

      if (!state.isSubmitModification) {
        api
          .postModification(plan.name, content, 1)
          .then(function () {
            state.isSubmitModification = true
            done()
          })
          .catch(handleError)
      } else if (!state.isSubmitReply) {
        api
          .postModification(undefined, content, 0)
          .then(function () {
            state.isSubmitReply = true
            done()
          })
          .catch(handleError)
      } else {
        api
          .postMessage(undefined, plan.name, content)
          .then(done)
          .catch(handleError)
      }
    }

    function startModification(row) {
      state.selectedPlan = { name: row.message.title, id: row.message.id }
      state.isSubmitModification = false
      state.inputValue = ""
      render()
      focusInput()
    }

    function startReply(row) {
      state.selectedPlan = { name: row.message.title, id: row.message.id }
      state.isSubmitReply = false
      render()
      focusInput()
    }

    function focusInput() {
      var input = root.querySelector(".msgw-input")
      if (input) setTimeout(function () {
        input.focus()
      }, 0)
    }

    // ---- renderers (left = uAssist team, right = doctor) ------------------
    function avatar(row) {
      if (row.role === "UASSIST TEAM") {
        return el("div", { class: "msgw-avatar msgw-avatar--logo" })
      }
      return el("div", { class: "msgw-avatar" }, [
        initials(row.lastname, row.firstname),
      ])
    }

    function statusLine(text) {
      return el("div", { class: "msgw-status" }, [
        el("span", { class: "msgw-status-icon", text: "✓" }),
        text,
      ])
    }

    function messageBubble(row, extraClass) {
      var bubble = el("div", { class: "msgw-bubble " + (extraClass || "") })
      if (row.message.subject)
        bubble.appendChild(
          el("div", { class: "msgw-subject", text: row.message.subject }),
        )
      if (row.message.title)
        bubble.appendChild(
          el("div", { class: "msgw-title", text: row.message.title }),
        )
      bubble.appendChild(
        el("div", { class: "msgw-text", text: row.message.text || "" }),
      )
      return bubble
    }

    function renderLeft(row) {
      var wrap = el("div", { class: "msgw-row msgw-row--left" }, [
        el("div", { class: "msgw-head" }, [
          avatar(row),
          el("div", { class: "msgw-meta" }, [
            el("div", { class: "msgw-name" }, [
              el("span", { text: row.lastname + " " + row.firstname }),
              el("span", { class: "msgw-divider" }),
              el("span", { class: "msgw-role", text: row.role }),
            ]),
            el("div", { class: "msgw-time", text: formatTime(row.time) }),
          ]),
        ]),
        messageBubble(row, "msgw-bubble--left"),
      ])

      if (row.messageStatus === "MESSAGE_SELECTED")
        wrap.appendChild(statusLine("Selected"))
      if (row.messageStatus === "MESSAGE_REPLIED")
        wrap.appendChild(statusLine("Replied"))

      if (row.messageStatus === "MESSAGE_MODIFICATION_REQUEST") {
        var canStart =
          MODIFICATION_STATUSES.indexOf(state.caseDisposition) !== -1 &&
          !!row.buttonEnable
        wrap.appendChild(
          el("div", { class: "msgw-actions" }, [
            el(
              "button",
              {
                class: "msgw-btn msgw-btn--primary",
                disabled: canStart ? null : "disabled",
                onClick: function () {
                  startModification(row)
                },
              },
              ["start modification request", el("span", { text: " →" })],
            ),
          ]),
        )
      }

      if (row.messageStatus === "MESSAGE_WITH_REPLY") {
        wrap.appendChild(
          el("div", { class: "msgw-actions" }, [
            el(
              "button",
              {
                class: "msgw-btn msgw-btn--primary",
                disabled: row.buttonEnable ? null : "disabled",
                onClick: function () {
                  startReply(row)
                },
              },
              ["Reply"],
            ),
          ]),
        )
      }
      return wrap
    }

    function renderRight(row) {
      var wrap = el("div", { class: "msgw-row msgw-row--right" }, [
        el("div", { class: "msgw-time msgw-time--right", text: formatTime(row.time) }),
        messageBubble(row, "msgw-bubble--right"),
      ])
      if (row.messageStatus === "MESSAGE_MODIFICATION_REQUEST_SUBMITTED")
        wrap.appendChild(statusLine("Modification request submitted"))
      return wrap
    }

    function renderSystem(row) {
      return el("div", { class: "msgw-banner msgw-banner--info" }, [
        row.message.text || "",
      ])
    }

    function renderRow(row) {
      if (row.messageStatus === "CASE_SYSTEM_MESSAGE") return renderSystem(row)
      return row.role === "UASSIST TEAM" ? renderLeft(row) : renderRight(row)
    }

    function renderEmpty() {
      return el("div", { class: "msgw-empty" }, [
        el("div", { class: "msgw-empty-title", text: "No comment" }),
        el("div", {
          class: "msgw-empty-sub",
          text:
            "You can send modification request to uAssist once your plan is ready to review",
        }),
      ])
    }

    function composerDisabled() {
      if (!state.selectedPlan.id) return true
      if (state.messages.length === 0) return true
      if (INPUT_ENABLED_STATUSES.indexOf(state.caseDisposition) === -1)
        return true
      if (
        state.caseDisposition === STATUS.ATTENTION_NEEDED &&
        !state.isSubmitReply &&
        !state.selectedPlan.id
      )
        return true
      return false
    }

    function render() {
      root.innerHTML = ""

      var header = el("div", { class: "msgw-header" }, [
        el("span", { class: "msgw-header-title", text: "Messages" }),
        el("button", {
          class: "msgw-close",
          text: "×",
          onClick: function () {
            root.innerHTML = ""
          },
        }),
      ])

      var thread = el("div", { class: "msgw-thread" })

      if (state.loading) {
        thread.appendChild(el("div", { class: "msgw-loading", text: "Loading…" }))
      } else if (state.error) {
        thread.appendChild(
          el("div", { class: "msgw-banner msgw-banner--error" }, [
            "Failed to load messages.",
          ]),
        )
      } else if (state.messages.length === 0 && state.history.length === 0) {
        thread.appendChild(renderEmpty())
      } else {
        if (state.caseDisposition === STATUS.MODIFICATION_REQUESTED)
          thread.appendChild(
            el("div", { class: "msgw-banner msgw-banner--info" }, [
              "Planning in progress",
            ]),
          )
        state.messages.forEach(function (row) {
          thread.appendChild(renderRow(row))
        })
        state.history.forEach(function (row) {
          thread.appendChild(renderRow(row))
        })
      }

      var input = el("textarea", {
        class: "msgw-input",
        rows: "1",
        placeholder: "Enter message or modification request here",
        disabled: composerDisabled() ? "disabled" : null,
        onInput: function (e) {
          state.inputValue = e.target.value
          e.target.style.height = "auto"
          e.target.style.height = Math.min(e.target.scrollHeight, 160) + "px"
          var sendBtn = root.querySelector(".msgw-send")
          if (sendBtn) sendBtn.disabled = !state.inputValue.trim()
        },
        onKeydown: function (e) {
          if (e.key === "Enter" && !e.shiftKey) {
            e.preventDefault()
            send()
          }
        },
      })
      input.value = state.inputValue

      var sendBtn = el("button", {
        class: "msgw-send",
        text: "➤",
        disabled: state.inputValue.trim() ? null : "disabled",
        onClick: send,
      })

      var composer = el("div", { class: "msgw-composer" }, [
        el("div", { class: "msgw-composer-box" }, [input, sendBtn]),
      ])

      root.appendChild(header)
      root.appendChild(thread)
      root.appendChild(composer)
    }

    render()
    refresh()

    return {
      reload: refresh,
      version: VERSION,
    }
  }

  window.MessageWidget = { mount: mount, version: VERSION }
})()
