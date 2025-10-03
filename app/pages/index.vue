<template>
  <div class="index-page">
    <h1 class="text-black">Split PDF Tool</h1>
    <div class="flex flex-col items-center">
      <form
        @submit.prevent="handleFileUpload"
        class="text-black flex flex-col items-center justify-center mb-6"
      >
        <div class="my-2 p-4">
          <label for="pdfFile">Upload Excel File:</label>
          <UInput
            type="file"
            id="excelFile"
            accept="application/excel, application/vnd.openxmlformats-officedocument.spreadsheetml.sheet, application/vnd.ms-excel"
            @change="onExcelFileChange"
          />
        </div>
        <div class="my-2 p-4">
          <label for="pdfFile">Upload PDF File:</label>
          <UInput
            type="file"
            id="pdfFile"
            accept="application/pdf"
            @change="onFileChange"
          />
        </div>

        <!-- <button type="submit" :disabled="!pdfFile || !excelFile">Upload</button> -->
        <UButton
          class="mt-4"
          icon="i-lucide-rocket"
          size="md"
          color="primary"
          variant="solid"
          type="submit"
          :disabled="!pdfFile || !excelFile"
          >Button</UButton
        >
      </form>
      <div>
        <UTimeline
          v-model="active"
          :items="items"
          orientation="vertical"
      
        />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from "vue";
import { PDFDocument } from "pdf-lib";
import * as XLSX from "xlsx";
import JSZip from "jszip";
import * as pdfjsLib from "pdfjs-dist/legacy/build/pdf.mjs";
import pdfjsWorker from "pdfjs-dist/build/pdf.worker.mjs?url";
pdfjsLib.GlobalWorkerOptions.workerSrc = pdfjsWorker;

const pdfFile = ref(null);
const excelFile = ref(null);
const active = ref(null);
const items = [
  {
    date: "รับไฟล์ Excel และ PDF",
    icon: "streamline-freehand:book-library-shelf-1",
    class: 'text-black font-bold ',
  },
  {
    date: "อ่านข้อมูลจาก Excel",
    icon: "streamline-freehand:app-window-search-text",
     class: 'text-black font-bold ',
  },
  {
    date: "แยกหน้า PDF ตามข้อมูลใน Excel",
    icon: "streamline-freehand:connect-device-exchange",
     class: 'text-black font-bold ',
  },
  {
    date: "สร้างไฟล์ ZIP สำหรับดาวน์โหลด",
    icon: "streamline-freehand:archive-box",
     class: 'text-black font-bold ',
  },

  {
    date: "เสร็จสิ้น",
    icon: "fluent-mdl2:accept-medium",
     class: 'text-black font-bold ',
  },
];

function onFileChange(event) {
  active.value = 0; // รีเซ็ตสถานะ
  const file = event.target.files[0];
  if (file && file.type === "application/pdf") {
    pdfFile.value = file;
  } else {
    pdfFile.value = null;
    alert("Please select a valid PDF file.");
  }
}
function onExcelFileChange(event) {
  active.value = 0; // รีเซ็ตสถานะ
  const file = event.target.files[0];
  if (
    file &&
    (file.type === "application/excel" ||
      file.type ===
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" ||
      file.type === "application/vnd.ms-excel")
  ) {
    excelFile.value = file;
  } else {
    excelFile.value = null;
    alert("Please select a valid Excel file.");
  }
}
async function readExcelFile() {
  if (!excelFile.value) return;
  try {
    console.log(excelFile.value);
    const data = await excelFile.value.arrayBuffer();

    const workbook = XLSX.read(data, { type: "array" });
    const firstSheetName = workbook.SheetNames[0];
    const worksheet = workbook.Sheets[firstSheetName];
    const jsonData = XLSX.utils.sheet_to_json(worksheet);
    const objectKeys = {};
    jsonData.forEach((item) => {
      objectKeys[item[Object.keys(item)[1]]] = item[Object.keys(item)[0]];
    });
    active.value = 1; // อัพเดตสถานะ
    return objectKeys;
  } catch (err) {
    console.error("Error reading Excel file:", err);
    alert("An error occurred while reading the Excel file.");
  }
}

async function handleFileUpload() {
  if (!pdfFile.value) return;

  // สมมติว่า readExcelFile() คืน mapping: { [key: string]: string }
  const nameMap = await readExcelFile();

  try {
    // อ่านไฟล์ครั้งเดียว แล้วทำสำเนาแยกให้แต่ละไลบรารี
    const originalAB = await pdfFile.value.arrayBuffer();
    const abForPdfJs = originalAB.slice(0);
    const abForPdfLib = originalAB.slice(0);

    // pdf.js ใช้ก้อนของตัวเอง
    const pdf = await pdfjsLib.getDocument({ data: new Uint8Array(abForPdfJs) })
      .promise;

    // pdf-lib ใช้ก้อนของตัวเอง (ส่งเป็น Uint8Array ก็ได้)
    const pdfLibDoc = await PDFDocument.load(new Uint8Array(abForPdfLib));

    const totalPages = pdf.numPages;
    const zip = new JSZip();

    // helper: ทำชื่อไฟล์ให้ปลอดภัย
    const setFileName = (name) => {
      if (!name) return "page";
      return `โรงเรียน${name.replace(/[\/\\?%*:|"<>]/g, "_").trim()}`.substring(
        0,
        50
      );
    };

    // กันชื่อซ้ำใน zip
    const used = new Set();
    active.value = 3; // อัพเดตสถานะ
    for (let pageNum = 1; pageNum <= totalPages; pageNum++) {
      const page = await pdf.getPage(pageNum);
      const textContent = await page.getTextContent();
      const items = (textContent.items || []).map((i) => i.str).filter(Boolean);

      // เผื่อ items[2] ไม่มี ให้ fallback เป็น page_x
      const key = items[2];
      const rawBase = (key && nameMap[key]) || `page_${pageNum}`;
      let baseName = setFileName(rawBase);

      // ถ้าชนกันใน zip ให้เติม (1), (2), ...
      let finalName = baseName;
      let c = 1;
      while (used.has(finalName)) {
        finalName = `${baseName}(${c++})`;
      }
      used.add(finalName);

      const newPDF = await PDFDocument.create();
      const [copiedPage] = await newPDF.copyPages(pdfLibDoc, [pageNum - 1]);
      newPDF.addPage(copiedPage);
      const pdfBytes = await newPDF.save(); // Uint8Array

      zip.file(`${finalName}.pdf`, pdfBytes);
    }

    active.value = 4;
    const zipBlob = await zip.generateAsync({ type: "blob" });
    const url = URL.createObjectURL(zipBlob);
    const link = document.createElement("a");
    link.href = url;
    link.download = "output.zip";
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);

    // เคลียร์ state
    active.value = 5;

    pdfFile.value = null;
    excelFile.value = null;
  } catch (err) {
    console.error("Error processing PDF:", err);
    alert(`เกิดข้อผิดพลาดขณะประมวลผล PDF: ${err?.message || err}`);
  }
}
</script>

<style scoped>
.index-page {
  max-width: 800px;
  margin: 40px auto;
  padding: 24px;
  border: 1px solid #eee;
  border-radius: 8px;
  background: #fafafa;
}
label {
  display: block;
  margin-bottom: 8px;
}
input[type="file"] {
  margin-bottom: 16px;
}
button {
  padding: 8px 16px;
}
</style>
