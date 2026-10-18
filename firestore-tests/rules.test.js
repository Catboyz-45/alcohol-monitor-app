// ทดสอบ firestore.rules กับ Firestore Emulator
// รัน: cd firestore-tests && npm ci && npm test   (ต้องมี Java 21+)
import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  collection,
  setDoc,
} from 'firebase/firestore';

const OFFICER = 'officer-1';
const STRANGER = 'stranger-1';

let env;

// เอกสารที่ถูกต้องตามที่แอปส่ง (FirestoreRepository.toFirestoreFields)
function measurement(id, uid, overrides = {}) {
  return {
    id,
    name: 'สมชาย ใจดี',
    idCard: '1101700203450',
    age: 34,
    licensePlate: '1กข 4521',
    province: 'กรุงเทพมหานคร',
    alcoholValue: 62.4,
    status: 'DRUNK',
    timestamp: Timestamp.fromDate(new Date('2026-10-18T09:00:00Z')),
    createdBy: uid,
    ...overrides,
  };
}

function db(uid) {
  return uid
    ? env.authenticatedContext(uid).firestore()
    : env.unauthenticatedContext().firestore();
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-alcohol-monitor',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(doc(admin, 'officers', OFFICER), { name: 'เจ้าหน้าที่ทดสอบ' });
    await setDoc(
      doc(admin, 'measurements', 'existing'),
      measurement('existing', OFFICER),
    );
  });
});

describe('อ่านข้อมูลผู้รับการตรวจ', () => {
  test('ไม่ได้ล็อกอินอ่านไม่ได้', async () => {
    await assertFails(getDocs(collection(db(), 'measurements')));
    await assertFails(getDoc(doc(db(), 'measurements', 'existing')));
  });

  test('ล็อกอินแล้วแต่ไม่อยู่ใน officers อ่านไม่ได้', async () => {
    await assertFails(getDocs(collection(db(STRANGER), 'measurements')));
  });

  test('เจ้าหน้าที่อ่านได้', async () => {
    await assertSucceeds(getDocs(collection(db(OFFICER), 'measurements')));
  });
});

describe('บันทึกผลตรวจ', () => {
  test('เจ้าหน้าที่บันทึกข้อมูลที่ถูกต้องได้', async () => {
    await assertSucceeds(
      setDoc(doc(db(OFFICER), 'measurements', 'r1'), measurement('r1', OFFICER)),
    );
  });

  test('คนนอก officers บันทึกไม่ได้', async () => {
    await assertFails(
      setDoc(
        doc(db(STRANGER), 'measurements', 'r1'),
        measurement('r1', STRANGER),
      ),
    );
  });

  test('ปลอม createdBy เป็นคนอื่นไม่ได้', async () => {
    await assertFails(
      setDoc(doc(db(OFFICER), 'measurements', 'r1'), measurement('r1', 'other')),
    );
  });

  test('id ในเอกสารต้องตรงกับ document id', async () => {
    await assertFails(
      setDoc(doc(db(OFFICER), 'measurements', 'r1'), measurement('r2', OFFICER)),
    );
  });

  const invalid = {
    'เลขบัตรไม่ครบ 13 หลัก': { idCard: '12345' },
    'เลขบัตรแบบปิดไว้': { idCard: 'XXXXXXXXXX450' },
    'อายุเป็นข้อความ': { age: '34' },
    'อายุเกิน 120': { age: 150 },
    'ค่าแอลกอฮอล์เกิน 100': { alcoholValue: 101 },
    'สถานะไม่รู้จัก': { status: 'OK' },
    'timestamp เป็นข้อความ': { timestamp: '2026-10-18T09:00:00Z' },
    'ชื่อว่าง': { name: '' },
    'มี field แปลกปลอม': { isAdmin: true },
  };
  for (const [name, overrides] of Object.entries(invalid)) {
    test(`ปฏิเสธข้อมูลผิดรูปแบบ: ${name}`, async () => {
      await assertFails(
        setDoc(
          doc(db(OFFICER), 'measurements', 'bad'),
          measurement('bad', OFFICER, overrides),
        ),
      );
    });
  }

  test('ขาด field ที่จำเป็นไม่ได้', async () => {
    const data = measurement('r1', OFFICER);
    delete data.province;
    await assertFails(setDoc(doc(db(OFFICER), 'measurements', 'r1'), data));
  });
});

describe('ลบข้อมูล', () => {
  test('เจ้าหน้าที่ลบได้', async () => {
    await assertSucceeds(deleteDoc(doc(db(OFFICER), 'measurements', 'existing')));
  });

  test('คนนอก officers ลบไม่ได้', async () => {
    await assertFails(deleteDoc(doc(db(STRANGER), 'measurements', 'existing')));
  });
});

describe('รายชื่อเจ้าหน้าที่', () => {
  test('เพิ่มตัวเองเป็นเจ้าหน้าที่ไม่ได้', async () => {
    await assertFails(setDoc(doc(db(STRANGER), 'officers', STRANGER), {}));
  });

  test('อ่านได้เฉพาะเอกสารของตัวเอง', async () => {
    await assertSucceeds(getDoc(doc(db(OFFICER), 'officers', OFFICER)));
    await assertFails(getDoc(doc(db(STRANGER), 'officers', OFFICER)));
  });
});

describe('collection อื่น', () => {
  test('ปิดทั้งหมด', async () => {
    await assertFails(setDoc(doc(db(OFFICER), 'anything', 'x'), { a: 1 }));
    await assertFails(getDoc(doc(db(OFFICER), 'anything', 'x')));
  });
});
