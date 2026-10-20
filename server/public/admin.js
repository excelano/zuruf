// admin.js
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

'use strict';

const storageKey = 'zuruf-admin-token';
const errors = {
  unauthorized: 'That admin token was not accepted.',
  not_found: 'That no longer exists. The list has been refreshed.',
  invalid_name: 'A group name is 1 to 40 characters on one line.',
  https_required: 'The server only answers over HTTPS.',
};

let token = null;
let state = { users: [], groups: [] };
const created = [];

const $ = (id) => document.getElementById(id);

function el(tag, props = {}, ...children) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(props)) {
    if (key === 'class') node.className = value;
    else if (key.startsWith('on')) node.addEventListener(key.slice(2), value);
    else if (key.includes('-')) node.setAttribute(key, value);
    else node[key] = value;
  }
  for (const child of children) {
    node.append(child instanceof Node ? child : document.createTextNode(String(child)));
  }
  return node;
}

function storage(kind) {
  try { return window[kind]; } catch { return null; }
}

function savedToken() {
  for (const kind of ['sessionStorage', 'localStorage']) {
    try {
      const value = storage(kind)?.getItem(storageKey);
      if (value) return value;
    } catch { }
  }
  return null;
}

function saveToken(value, remember) {
  try { storage(remember ? 'localStorage' : 'sessionStorage')?.setItem(storageKey, value); } catch { }
}

function forgetToken() {
  for (const kind of ['sessionStorage', 'localStorage']) {
    try { storage(kind)?.removeItem(storageKey); } catch { }
  }
}

async function api(method, path, body) {
  const response = await fetch('/v1/admin' + path, {
    method,
    headers: {
      Authorization: 'Bearer ' + token,
      ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
    cache: 'no-store',
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error(errors[data.error] || `The server answered ${response.status}${data.error ? ': ' + data.error : ''}.`);
    error.status = response.status;
    error.code = data.error;
    throw error;
  }
  return data;
}

function say(text, ok = false) {
  const message = $('message');
  message.textContent = text;
  message.className = ok ? 'ok' : '';
  message.hidden = !text;
}

// Runs an action, then reloads everything, so the page always shows the server's state.
async function act(work, success) {
  say('');
  try {
    await work();
    if (success) say(success, true);
  } catch (error) {
    if (error.status === 401) return signOut(error.message);
    say(error.message);
  }
  await load();
}

async function load() {
  try {
    state = await api('GET', '/users');
    render();
  } catch (error) {
    if (error.status === 401) return signOut(error.message);
    say(error.message);
  }
}

function showSignIn(message) {
  $('sign-in').hidden = false;
  $('console').hidden = true;
  $('sign-out').hidden = true;
  $('token').value = '';
  if (message) {
    const form = $('sign-in-form');
    form.querySelector('.error')?.remove();
    form.append(el('p', { class: 'hint error' }, message));
  }
  $('token').focus();
}

function signOut(message) {
  token = null;
  forgetToken();
  showSignIn(message);
}

async function signIn(value, remember) {
  token = value;
  try {
    state = await api('GET', '/users');
  } catch (error) {
    token = null;
    return showSignIn(error.message);
  }
  if (remember !== undefined) saveToken(value, remember);
  $('sign-in').hidden = true;
  $('console').hidden = false;
  $('sign-out').hidden = false;
  render();
}

function ago(seconds) {
  if (!seconds) return 'never opened';
  const minutes = Math.round((Date.now() / 1000 - seconds) / 60);
  if (minutes < 2) return 'opened just now';
  if (minutes < 60) return `opened ${minutes} minutes ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `opened ${hours} hour${hours === 1 ? '' : 's'} ago`;
  const days = Math.round(hours / 24);
  return `opened ${days} day${days === 1 ? '' : 's'} ago`;
}

function when(seconds) {
  return new Date(seconds * 1000).toLocaleString(undefined, { weekday: 'short', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' });
}

// A delete button that asks once more before acting.
function deleteButton(label, question, work) {
  let armed = null;
  const button = el('button', { class: 'danger', type: 'button' }, label);
  button.addEventListener('click', () => {
    if (armed) {
      clearTimeout(armed);
      button.disabled = true;
      return work();
    }
    button.textContent = question;
    button.classList.add('confirm');
    armed = setTimeout(() => {
      armed = null;
      button.textContent = label;
      button.classList.remove('confirm');
    }, 5000);
  });
  return button;
}

function render() {
  const people = state.users.filter((user) => !user.is_bot);
  const nameOf = new Map(state.users.map((user) => [user.id, user.display_name]));
  const groupsOf = (id) => state.groups.filter((group) => group.member_ids.includes(id)).map((group) => group.name);

  $('invites').replaceChildren(...created.map((invite) => el('li', {},
    el('span', { class: 'code' }, invite.code),
    el('span', { class: 'expires' }, 'until ' + when(invite.expires_at)),
    el('button', { class: 'quiet', type: 'button', onclick: (event) => copy(invite.code, event.currentTarget) }, 'Copy'),
  )));

  $('people').replaceChildren(...(people.length ? people.map((user) => el('li', {},
    el('span', { class: 'name' }, user.display_name),
    el('span', { class: 'detail' }, [ago(user.last_seen), groupsOf(user.id).join(', ')].filter(Boolean).join(' · ')),
    el('span', { class: 'actions' }, deleteButton('Delete', `Delete ${user.display_name} and their messages?`,
      () => act(() => api('DELETE', '/users/' + user.id), `Deleted ${user.display_name}.`))),
  )) : [el('li', { class: 'detail' }, 'Nobody has joined yet. Make an invite code above.')]));

  $('groups').replaceChildren(...state.groups.map((group) => {
    const outside = people.filter((user) => !group.member_ids.includes(user.id));
    const name = el('span', { class: 'name' }, group.name);
    const head = el('div', { class: 'head' }, name,
      el('button', { class: 'quiet', type: 'button', onclick: () => rename(group, head) }, 'Rename'),
      deleteButton('Delete', `Delete ${group.name} and its messages?`,
        () => act(() => api('DELETE', '/groups/' + group.id), `Deleted ${group.name}.`)),
    );
    const members = el('ul', { class: 'members' }, ...(group.member_ids.length ? group.member_ids.map((id) => el('li', {},
      nameOf.get(id) ?? 'Unknown',
      el('button', { type: 'button', title: 'Remove from ' + group.name, 'aria-label': `Remove ${nameOf.get(id)} from ${group.name}`,
        onclick: () => act(() => api('DELETE', `/groups/${group.id}/members/${id}`)) }, '×'),
    )) : [el('li', { class: 'empty' }, 'No members yet.')]));
    const picker = el('select', { 'aria-label': 'Person to add to ' + group.name },
      el('option', { value: '' }, outside.length ? 'Add someone…' : 'Everyone is in this group'),
      ...outside.map((user) => el('option', { value: user.id }, user.display_name)));
    picker.disabled = !outside.length;
    picker.addEventListener('change', () => picker.value &&
      act(() => api('POST', `/groups/${group.id}/members`, { user_id: picker.value })));
    return el('div', { class: 'group' }, head, members, picker);
  }));
}

function rename(group, head) {
  const input = el('input', { value: group.name, maxLength: 40, required: true, 'aria-label': 'New name for ' + group.name });
  const form = el('form', { class: 'row', onsubmit: (event) => {
    event.preventDefault();
    act(() => api('PATCH', '/groups/' + group.id, { name: input.value }), `Renamed to ${input.value.trim()}.`);
  } }, input,
    el('button', { type: 'submit' }, 'Save'),
    el('button', { class: 'quiet', type: 'button', onclick: render }, 'Cancel'));
  head.replaceWith(form);
  input.select();
}

async function copy(text, button) {
  try {
    await navigator.clipboard.writeText(text);
    button.textContent = 'Copied';
    setTimeout(() => { button.textContent = 'Copy'; }, 1500);
  } catch {
    const range = document.createRange();
    range.selectNodeContents(button.parentElement.querySelector('.code'));
    getSelection().removeAllRanges();
    getSelection().addRange(range);
  }
}

$('sign-in-form').addEventListener('submit', (event) => {
  event.preventDefault();
  signIn($('token').value.trim(), $('remember').checked);
});

$('sign-out').addEventListener('click', () => signOut());

$('invite-form').addEventListener('submit', (event) => {
  event.preventDefault();
  act(async () => {
    created.unshift(await api('POST', '/invites', { expires_days: Number($('invite-days').value) }));
  });
});

$('group-form').addEventListener('submit', (event) => {
  event.preventDefault();
  const name = $('group-name').value;
  act(async () => {
    await api('POST', '/groups', { name });
    $('group-name').value = '';
  }, `Created ${name.trim()}.`);
});

const saved = savedToken();
if (saved) signIn(saved);
else showSignIn();
