--Represents the patients registered at an insurance company--
CREATE TABLE "patients" (
    "id" INTEGER,
    "first_name" TEXT NOT NULL,
    "last_name" TEXT NOT NULL,
    "gender" TEXT NOT NULL CHECK  ("gender" IN ('F', 'M')),
    "age" INTEGER NOT NULL,
    "country" TEXT NOT NULL,
    PRIMARY KEY ("id")
);

--Represents the insurnace companies--
CREATE TABLE "insurers" (
    "id" INTEGER,
   "insurer_company" TEXT NOT NULL,
   PRIMARY KEY ("id")
);

--Represents the hospitals visited by the patients--
CREATE TABLE "hospitals" (
    "id" INTEGER,
    "hospital_name" TEXT NOT NULL UNIQUE,
    PRIMARY KEY ("id")

);

--Represents claims requested by the patients--
CREATE TABLE "claims"(
    "id" INTEGER,
    "patient_id" INTEGER,
    "insurer_id" INTEGER,
    "hospital_id" INTEGER,
    "submitted" DATE NOT NULL,
    "responded" DATE,
   "overall_status" TEXT CHECK ("overall_status" IN ("partially approved", "rejected", "approved")),
    "total" NUMERIC NOT NULL,
    PRIMARY KEY ("id"),
    FOREIGN KEY ("patient_id") REFERENCES "patients" ("id"),
    FOREIGN KEY ("insurer_id")  REFERENCES "insurers" ("id"),
    FOREIGN KEY ("hospital_id")  REFERENCES "hospitals" ("id")
);


--Represents the services a patient underwent under one claim--
CREATE TABLE "medicalServices" (
    "id" INTEGER,
    "claim_id" INTEGER,
    "service_type" TEXT NOT NULL,
    "price" NUMERIC NOT NULL,
    PRIMARY KEY ("id"),
    FOREIGN KEY ("claim_id") REFERENCES "claims"("id")
);

--Represents the services' status and reason--
CREATE TABLE "serviceStatus" (
    "id" INTEGER,
    "medicalService_id" INTEGER,
    "status" TEXT NOT NULL CHECK ("status" IN ("pending", "progress", "rejected", "finished")),
    "reason" TEXT,
    PRIMARY KEY ("id"),
    FOREIGN KEY ("medicalService_id") REFERENCES "medicalServices"("id")
);

--Represents total of money the insurance company covered--
CREATE TABLE "payments" (
    "id" INTEGER,
    "claim_id" INTEGER,
    "covered_amount" NUMERIC NOT NULL,
    PRIMARY KEY ("id"),
    FOREIGN KEY ("claim_id") REFERENCES "claims"("id")
);

--Represents permiums paied by patients--
CREATE TABLE "permiums" (
    "id" INTEGER,
    "patient_id" INTEGER,
    "amount" NUMERIC NULL,
    "frequency" TEXT NOT NULL CHECK ("frequency" IN ("yearly", "monthly")),
    PRIMARY KEY ("id"),
    FOREIGN KEY ("patient_id") REFERENCES "patients"("id")
);

