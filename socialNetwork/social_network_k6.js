import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
    scenarios: {
        open_model: {
        executor: 'constant-arrival-rate',
        rate:1000,
        timeUnit: '1s',
        duration: '1m',
        preAllocatedVUs:4000 ,
        maxVUs: 5000000,
        },
    },
};

const charset = 'qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890'.split('');
const decset = '1234567890'.split('');

// Load env vars
const max_user_index = 962;

function stringRandom(length) {
  return Array(length).fill().map(() => charset[Math.floor(Math.random() * charset.length)]).join('');
}

function decRandom(length) {
  return Array(length).fill().map(() => decset[Math.floor(Math.random() * decset.length)]).join('');
}

function compose_post() {
  const user_index = Math.floor(Math.random() * max_user_index);
  const username = `username_${user_index}`;
  const user_id = user_index.toString();
  let text = stringRandom(256);
  const num_user_mentions = Math.floor(Math.random() * 6);
  const num_urls = Math.floor(Math.random() * 6);
  const num_media = Math.floor(Math.random() * 5);
  let media_ids = '[';
  let media_types = '[';

  for (let i = 0; i < num_user_mentions; i++) {
    let user_mention_id;
    do {
      user_mention_id = Math.floor(Math.random() * max_user_index);
    } while (user_index === user_mention_id);
    text += ` @username_${user_mention_id}`;
  }

  for (let i = 0; i < num_urls; i++) {
    text += ` http://${stringRandom(64)}`;
  }

  for (let i = 0; i < num_media; i++) {
    const media_id = decRandom(18);
    media_ids += `"${media_id}",`;
    media_types += `"png",`;
  }

  media_ids = media_ids.slice(0, -1) + ']';
  media_types = media_types.slice(0, -1) + ']';

//   const method = 'POST';
//   const path = 'http://localhost:8080/wrk2-api/post/compose';
  const path = 'http://localhost:20001/wrk2-api/post/compose';
  const headers = {
    'Content-Type': 'application/x-www-form-urlencoded'
  };
  let body;
  if (num_media) {
    body = `username=${username}&user_id=${user_id}&text=${text}&media_ids=${media_ids}&media_types=${media_types}&post_type=0`;
  } else {
    body = `username=${username}&user_id=${user_id}&text=${text}&media_ids=&post_type=0`;
  }

  return http.post(path, body, {
    headers: headers
  })

//   return { method, path, headers, body };
}

function read_user_timeline() {
  const user_id = Math.floor(Math.random() * max_user_index).toString();
  const start = Math.floor(Math.random() * 101).toString();
  const stop = (parseInt(start) + 10).toString();

  const args = `user_id=${user_id}&start=${start}&stop=${stop}`;
  const method = 'GET';
  const headers = {
    'Content-Type': 'application/x-www-form-urlencoded'
  };
//   const path = `http://localhost:8080/wrk2-api/user-timeline/read?${args}`;
  const path = `http://localhost:20001/wrk2-api/user-timeline/read?${args}`;
  return http.get(path, {
    headers: headers
  })
}

function read_home_timeline() {
  const user_id = Math.floor(Math.random() * max_user_index).toString();
  const start = Math.floor(Math.random() * 101).toString();
  const stop = (parseInt(start) + 10).toString();

  const args = `user_id=${user_id}&start=${start}&stop=${stop}`;
  const method = 'GET';
  const headers = {
    'Content-Type': 'application/x-www-form-urlencoded'
  };
//   const path = `http://localhost:8080/wrk2-api/home-timeline/read?${args}`;
  const path = `http://localhost:20001/wrk2-api/home-timeline/read?${args}`;
  return http.get(path, {
    headers: headers
  })
}

function request() {
  // You can change the two ratios here to trigger which one to only run or which ones to run the most 
  const read_home_timeline_ratio = 0.0;
  const read_user_timeline_ratio = 0.0;

  const coin = Math.random();
  if (coin < read_home_timeline_ratio) {
    return read_home_timeline();
  } else if (coin < read_home_timeline_ratio + read_user_timeline_ratio) {
    return read_user_timeline();
  } else {
    return compose_post();
  }
}

export default function() {
    // const res = http.get('https://test-api.k6.io/');
    // const res = http.get('https://ms1024.utah.cloudlab.us:8443')
    const res = request()
    check(res, {
        'status is 200': (r) => r.status === 200,
        // 'protocol is HTTP/2': (r) => r.proto === 'HTTP/2.0',
      });
}