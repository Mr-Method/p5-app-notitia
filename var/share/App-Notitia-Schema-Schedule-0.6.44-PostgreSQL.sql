DROP TABLE "trainer" CASCADE;
CREATE TABLE "trainer" (
  "trainer_id" integer NOT NULL,
  "course_type_id" integer NOT NULL,
  PRIMARY KEY ("trainer_id", "course_type_id")
);
CREATE INDEX "trainer_idx_course_type_id" on "trainer" ("course_type_id");
CREATE INDEX "trainer_idx_trainer_id" on "trainer" ("trainer_id");

DROP TABLE "customer" CASCADE;
CREATE TABLE "customer" (
  "id" serial NOT NULL,
  "name" character varying(64) DEFAULT '' NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "customer_name" UNIQUE ("name")
);

DROP TABLE "training" CASCADE;
CREATE TABLE "training" (
  "recipient_id" integer NOT NULL,
  "course_type_id" integer NOT NULL,
  "status" character varying DEFAULT 'enroled' NOT NULL,
  "enroled" timestamp,
  "started" timestamp,
  "completed" timestamp,
  "expired" timestamp,
  PRIMARY KEY ("recipient_id", "course_type_id")
);
CREATE INDEX "training_idx_course_type_id" on "training" ("course_type_id");
CREATE INDEX "training_idx_recipient_id" on "training" ("recipient_id");

DROP TABLE "job" CASCADE;
CREATE TABLE "job" (
  "id" serial NOT NULL,
  "name" character varying(32) DEFAULT '' NOT NULL,
  "command" character varying(1024),
  PRIMARY KEY ("id")
);

DROP TABLE "location" CASCADE;
CREATE TABLE "location" (
  "id" serial NOT NULL,
  "address" character varying(64) DEFAULT '' NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "location_address" UNIQUE ("address")
);

DROP TABLE "person" CASCADE;
CREATE TABLE "person" (
  "id" serial NOT NULL,
  "next_of_kin_id" integer,
  "active" boolean DEFAULT '0' NOT NULL,
  "password_expired" boolean DEFAULT '1' NOT NULL,
  "badge_expires" timestamp,
  "dob" timestamp,
  "joined" timestamp,
  "resigned" timestamp,
  "subscription" timestamp,
  "badge_id" smallint,
  "rows_per_page" smallint DEFAULT 20 NOT NULL,
  "shortcode" character varying(8) DEFAULT '' NOT NULL,
  "name" character varying(64) DEFAULT '' NOT NULL,
  "password" character varying(128) DEFAULT '' NOT NULL,
  "first_name" character varying(32) DEFAULT '' NOT NULL,
  "last_name" character varying(32) DEFAULT '' NOT NULL,
  "address" character varying(64) DEFAULT '' NOT NULL,
  "postcode" character varying(16) DEFAULT '' NOT NULL,
  "location" character varying(24) DEFAULT '' NOT NULL,
  "coordinates" character varying(16) DEFAULT '' NOT NULL,
  "email_address" character varying(64) DEFAULT '' NOT NULL,
  "mobile_phone" character varying(16) DEFAULT '' NOT NULL,
  "home_phone" character varying(16) DEFAULT '' NOT NULL,
  "totp_secret" character varying(16) DEFAULT '' NOT NULL,
  "region" character varying(1) DEFAULT '' NOT NULL,
  "notes" character varying(255) DEFAULT '' NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "person_badge_id" UNIQUE ("badge_id"),
  CONSTRAINT "person_email_address" UNIQUE ("email_address"),
  CONSTRAINT "person_name" UNIQUE ("name"),
  CONSTRAINT "person_shortcode" UNIQUE ("shortcode")
);
CREATE INDEX "person_idx_next_of_kin_id" on "person" ("next_of_kin_id");

DROP TABLE "type" CASCADE;
CREATE TABLE "type" (
  "id" serial NOT NULL,
  "name" character varying(32) DEFAULT '' NOT NULL,
  "type_class" character varying NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "type_name_type_class" UNIQUE ("name", "type_class")
);

DROP TABLE "endorsement" CASCADE;
CREATE TABLE "endorsement" (
  "recipient_id" integer NOT NULL,
  "points" smallint NOT NULL,
  "endorsed" timestamp NOT NULL,
  "type_code" character varying(25) DEFAULT '' NOT NULL,
  "uri" character varying(32) DEFAULT '' NOT NULL,
  "notes" character varying(255) DEFAULT '' NOT NULL,
  PRIMARY KEY ("recipient_id", "type_code", "endorsed"),
  CONSTRAINT "endorsement_uri" UNIQUE ("uri")
);
CREATE INDEX "endorsement_idx_recipient_id" on "endorsement" ("recipient_id");

DROP TABLE "rota" CASCADE;
CREATE TABLE "rota" (
  "id" serial NOT NULL,
  "type_id" integer NOT NULL,
  "date" timestamp,
  PRIMARY KEY ("id"),
  CONSTRAINT "rota_type_id_date" UNIQUE ("type_id", "date")
);
CREATE INDEX "rota_idx_type_id" on "rota" ("type_id");
CREATE INDEX "rota_idx_date" on "rota" ("date");

DROP TABLE "slot_criteria" CASCADE;
CREATE TABLE "slot_criteria" (
  "slot_type" character varying DEFAULT '0' NOT NULL,
  "certification_type_id" integer NOT NULL,
  PRIMARY KEY ("slot_type", "certification_type_id")
);
CREATE INDEX "slot_criteria_idx_certification_type_id" on "slot_criteria" ("certification_type_id");

DROP TABLE "certification" CASCADE;
CREATE TABLE "certification" (
  "recipient_id" integer NOT NULL,
  "type_id" integer NOT NULL,
  "completed" timestamp,
  "notes" character varying(255) DEFAULT '' NOT NULL,
  PRIMARY KEY ("recipient_id", "type_id")
);
CREATE INDEX "certification_idx_recipient_id" on "certification" ("recipient_id");
CREATE INDEX "certification_idx_type_id" on "certification" ("type_id");

DROP TABLE "incident" CASCADE;
CREATE TABLE "incident" (
  "id" serial NOT NULL,
  "raised" timestamp,
  "controller_id" integer NOT NULL,
  "category_id" integer NOT NULL,
  "committee_member_id" integer,
  "committee_informed" timestamp,
  "title" character varying(64) DEFAULT '' NOT NULL,
  "reporter" character varying(64) DEFAULT '' NOT NULL,
  "reporter_phone" character varying(16) DEFAULT '' NOT NULL,
  "category_other" character varying(16) DEFAULT '' NOT NULL,
  "notes" character varying(255) DEFAULT '' NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "incident_idx_category_id" on "incident" ("category_id");
CREATE INDEX "incident_idx_committee_member_id" on "incident" ("committee_member_id");
CREATE INDEX "incident_idx_controller_id" on "incident" ("controller_id");

DROP TABLE "role" CASCADE;
CREATE TABLE "role" (
  "member_id" integer NOT NULL,
  "type_id" integer NOT NULL,
  PRIMARY KEY ("member_id", "type_id")
);
CREATE INDEX "role_idx_member_id" on "role" ("member_id");
CREATE INDEX "role_idx_type_id" on "role" ("type_id");

DROP TABLE "shift" CASCADE;
CREATE TABLE "shift" (
  "id" serial NOT NULL,
  "rota_id" integer NOT NULL,
  "type_name" character varying DEFAULT 'day' NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "shift_idx_rota_id" on "shift" ("rota_id");

DROP TABLE "vehicle" CASCADE;
CREATE TABLE "vehicle" (
  "id" serial NOT NULL,
  "type_id" integer NOT NULL,
  "owner_id" integer,
  "aquired" timestamp,
  "disposed" timestamp,
  "colour" character varying(16) DEFAULT '' NOT NULL,
  "vrn" character varying(16) DEFAULT '' NOT NULL,
  "name" character varying(64) DEFAULT '' NOT NULL,
  "notes" character varying(255) DEFAULT '' NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "vehicle_vrn" UNIQUE ("vrn")
);
CREATE INDEX "vehicle_idx_owner_id" on "vehicle" ("owner_id");
CREATE INDEX "vehicle_idx_type_id" on "vehicle" ("type_id");

DROP TABLE "incident_party" CASCADE;
CREATE TABLE "incident_party" (
  "incident_id" integer NOT NULL,
  "incident_party_id" integer NOT NULL,
  PRIMARY KEY ("incident_id", "incident_party_id")
);
CREATE INDEX "incident_party_idx_incident_id" on "incident_party" ("incident_id");
CREATE INDEX "incident_party_idx_incident_party_id" on "incident_party" ("incident_party_id");

DROP TABLE "event" CASCADE;
CREATE TABLE "event" (
  "id" serial NOT NULL,
  "event_type_id" integer NOT NULL,
  "owner_id" integer NOT NULL,
  "start_rota_id" integer NOT NULL,
  "end_rota_id" integer,
  "vehicle_id" integer,
  "max_participents" smallint,
  "start_time" character varying(5) DEFAULT '' NOT NULL,
  "end_time" character varying(5) DEFAULT '' NOT NULL,
  "name" character varying(57) DEFAULT '' NOT NULL,
  "uri" character varying(64) DEFAULT '' NOT NULL,
  "description" character varying(128) DEFAULT '' NOT NULL,
  "notes" character varying(255) DEFAULT '' NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "event_uri" UNIQUE ("uri")
);
CREATE INDEX "event_idx_end_rota_id" on "event" ("end_rota_id");
CREATE INDEX "event_idx_event_type_id" on "event" ("event_type_id");
CREATE INDEX "event_idx_owner_id" on "event" ("owner_id");
CREATE INDEX "event_idx_start_rota_id" on "event" ("start_rota_id");
CREATE INDEX "event_idx_vehicle_id" on "event" ("vehicle_id");

DROP TABLE "journey" CASCADE;
CREATE TABLE "journey" (
  "id" serial NOT NULL,
  "completed" boolean DEFAULT '0' NOT NULL,
  "priority" character varying DEFAULT 'routine' NOT NULL,
  "original_priority" character varying DEFAULT 'routine' NOT NULL,
  "requested" timestamp,
  "delivered" timestamp,
  "controller_id" integer NOT NULL,
  "customer_id" integer NOT NULL,
  "pickup_id" integer NOT NULL,
  "dropoff_id" integer NOT NULL,
  "package_type_id" integer NOT NULL,
  "package_other" character varying(64) DEFAULT '' NOT NULL,
  "notes" character varying(255) DEFAULT '' NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "journey_idx_controller_id" on "journey" ("controller_id");
CREATE INDEX "journey_idx_customer_id" on "journey" ("customer_id");
CREATE INDEX "journey_idx_dropoff_id" on "journey" ("dropoff_id");
CREATE INDEX "journey_idx_package_type_id" on "journey" ("package_type_id");
CREATE INDEX "journey_idx_pickup_id" on "journey" ("pickup_id");

DROP TABLE "participent" CASCADE;
CREATE TABLE "participent" (
  "event_id" integer NOT NULL,
  "participent_id" integer NOT NULL,
  PRIMARY KEY ("event_id", "participent_id")
);
CREATE INDEX "participent_idx_event_id" on "participent" ("event_id");
CREATE INDEX "participent_idx_participent_id" on "participent" ("participent_id");

DROP TABLE "slot" CASCADE;
CREATE TABLE "slot" (
  "shift_id" integer NOT NULL,
  "operator_id" integer NOT NULL,
  "type_name" character varying DEFAULT '0' NOT NULL,
  "subslot" smallint NOT NULL,
  "bike_requested" boolean DEFAULT '0' NOT NULL,
  "vehicle_assigner_id" integer,
  "vehicle_id" integer,
  PRIMARY KEY ("shift_id", "type_name", "subslot")
);
CREATE INDEX "slot_idx_operator_id" on "slot" ("operator_id");
CREATE INDEX "slot_idx_shift_id" on "slot" ("shift_id");
CREATE INDEX "slot_idx_vehicle_id" on "slot" ("vehicle_id");
CREATE INDEX "slot_idx_vehicle_assigner_id" on "slot" ("vehicle_assigner_id");

DROP TABLE "transport" CASCADE;
CREATE TABLE "transport" (
  "event_id" integer NOT NULL,
  "vehicle_id" integer NOT NULL,
  "vehicle_assigner_id" integer NOT NULL,
  PRIMARY KEY ("event_id", "vehicle_id")
);
CREATE INDEX "transport_idx_event_id" on "transport" ("event_id");
CREATE INDEX "transport_idx_vehicle_id" on "transport" ("vehicle_id");
CREATE INDEX "transport_idx_vehicle_assigner_id" on "transport" ("vehicle_assigner_id");

DROP TABLE "vehicle_request" CASCADE;
CREATE TABLE "vehicle_request" (
  "event_id" integer NOT NULL,
  "type_id" integer NOT NULL,
  "quantity" smallint NOT NULL,
  PRIMARY KEY ("event_id", "type_id")
);
CREATE INDEX "vehicle_request_idx_event_id" on "vehicle_request" ("event_id");
CREATE INDEX "vehicle_request_idx_type_id" on "vehicle_request" ("type_id");

DROP TABLE "leg" CASCADE;
CREATE TABLE "leg" (
  "id" serial NOT NULL,
  "journey_id" integer NOT NULL,
  "operator_id" integer NOT NULL,
  "beginning_id" integer NOT NULL,
  "ending_id" integer NOT NULL,
  "vehicle_id" integer,
  "called" timestamp,
  "collection_eta" timestamp,
  "collected" timestamp,
  "delivered" timestamp,
  "on_station" timestamp,
  PRIMARY KEY ("id")
);
CREATE INDEX "leg_idx_beginning_id" on "leg" ("beginning_id");
CREATE INDEX "leg_idx_ending_id" on "leg" ("ending_id");
CREATE INDEX "leg_idx_journey_id" on "leg" ("journey_id");
CREATE INDEX "leg_idx_operator_id" on "leg" ("operator_id");
CREATE INDEX "leg_idx_vehicle_id" on "leg" ("vehicle_id");

ALTER TABLE "trainer" ADD CONSTRAINT "trainer_fk_course_type_id" FOREIGN KEY ("course_type_id")
  REFERENCES "type" ("id") DEFERRABLE;

ALTER TABLE "trainer" ADD CONSTRAINT "trainer_fk_trainer_id" FOREIGN KEY ("trainer_id")
  REFERENCES "person" ("id") DEFERRABLE;

ALTER TABLE "training" ADD CONSTRAINT "training_fk_course_type_id" FOREIGN KEY ("course_type_id")
  REFERENCES "type" ("id") DEFERRABLE;

ALTER TABLE "training" ADD CONSTRAINT "training_fk_recipient_id" FOREIGN KEY ("recipient_id")
  REFERENCES "person" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "person" ADD CONSTRAINT "person_fk_next_of_kin_id" FOREIGN KEY ("next_of_kin_id")
  REFERENCES "person" ("id") DEFERRABLE;

ALTER TABLE "endorsement" ADD CONSTRAINT "endorsement_fk_recipient_id" FOREIGN KEY ("recipient_id")
  REFERENCES "person" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "rota" ADD CONSTRAINT "rota_fk_type_id" FOREIGN KEY ("type_id")
  REFERENCES "type" ("id") DEFERRABLE;

ALTER TABLE "slot_criteria" ADD CONSTRAINT "slot_criteria_fk_certification_type_id" FOREIGN KEY ("certification_type_id")
  REFERENCES "type" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "certification" ADD CONSTRAINT "certification_fk_recipient_id" FOREIGN KEY ("recipient_id")
  REFERENCES "person" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "certification" ADD CONSTRAINT "certification_fk_type_id" FOREIGN KEY ("type_id")
  REFERENCES "type" ("id") DEFERRABLE;

ALTER TABLE "incident" ADD CONSTRAINT "incident_fk_category_id" FOREIGN KEY ("category_id")
  REFERENCES "type" ("id") DEFERRABLE;

ALTER TABLE "incident" ADD CONSTRAINT "incident_fk_committee_member_id" FOREIGN KEY ("committee_member_id")
  REFERENCES "person" ("id") DEFERRABLE;

ALTER TABLE "incident" ADD CONSTRAINT "incident_fk_controller_id" FOREIGN KEY ("controller_id")
  REFERENCES "person" ("id") DEFERRABLE;

ALTER TABLE "role" ADD CONSTRAINT "role_fk_member_id" FOREIGN KEY ("member_id")
  REFERENCES "person" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "role" ADD CONSTRAINT "role_fk_type_id" FOREIGN KEY ("type_id")
  REFERENCES "type" ("id") DEFERRABLE;

ALTER TABLE "shift" ADD CONSTRAINT "shift_fk_rota_id" FOREIGN KEY ("rota_id")
  REFERENCES "rota" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "vehicle" ADD CONSTRAINT "vehicle_fk_owner_id" FOREIGN KEY ("owner_id")
  REFERENCES "person" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "vehicle" ADD CONSTRAINT "vehicle_fk_type_id" FOREIGN KEY ("type_id")
  REFERENCES "type" ("id") DEFERRABLE;

ALTER TABLE "incident_party" ADD CONSTRAINT "incident_party_fk_incident_id" FOREIGN KEY ("incident_id")
  REFERENCES "incident" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "incident_party" ADD CONSTRAINT "incident_party_fk_incident_party_id" FOREIGN KEY ("incident_party_id")
  REFERENCES "person" ("id") DEFERRABLE;

ALTER TABLE "event" ADD CONSTRAINT "event_fk_end_rota_id" FOREIGN KEY ("end_rota_id")
  REFERENCES "rota" ("id") DEFERRABLE;

ALTER TABLE "event" ADD CONSTRAINT "event_fk_event_type_id" FOREIGN KEY ("event_type_id")
  REFERENCES "type" ("id") DEFERRABLE;

ALTER TABLE "event" ADD CONSTRAINT "event_fk_owner_id" FOREIGN KEY ("owner_id")
  REFERENCES "person" ("id") DEFERRABLE;

ALTER TABLE "event" ADD CONSTRAINT "event_fk_start_rota_id" FOREIGN KEY ("start_rota_id")
  REFERENCES "rota" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "event" ADD CONSTRAINT "event_fk_vehicle_id" FOREIGN KEY ("vehicle_id")
  REFERENCES "vehicle" ("id") DEFERRABLE;

ALTER TABLE "journey" ADD CONSTRAINT "journey_fk_controller_id" FOREIGN KEY ("controller_id")
  REFERENCES "person" ("id") DEFERRABLE;

ALTER TABLE "journey" ADD CONSTRAINT "journey_fk_customer_id" FOREIGN KEY ("customer_id")
  REFERENCES "customer" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "journey" ADD CONSTRAINT "journey_fk_dropoff_id" FOREIGN KEY ("dropoff_id")
  REFERENCES "location" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "journey" ADD CONSTRAINT "journey_fk_package_type_id" FOREIGN KEY ("package_type_id")
  REFERENCES "type" ("id") DEFERRABLE;

ALTER TABLE "journey" ADD CONSTRAINT "journey_fk_pickup_id" FOREIGN KEY ("pickup_id")
  REFERENCES "location" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "participent" ADD CONSTRAINT "participent_fk_event_id" FOREIGN KEY ("event_id")
  REFERENCES "event" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "participent" ADD CONSTRAINT "participent_fk_participent_id" FOREIGN KEY ("participent_id")
  REFERENCES "person" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "slot" ADD CONSTRAINT "slot_fk_operator_id" FOREIGN KEY ("operator_id")
  REFERENCES "person" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "slot" ADD CONSTRAINT "slot_fk_shift_id" FOREIGN KEY ("shift_id")
  REFERENCES "shift" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "slot" ADD CONSTRAINT "slot_fk_vehicle_id" FOREIGN KEY ("vehicle_id")
  REFERENCES "vehicle" ("id") DEFERRABLE;

ALTER TABLE "slot" ADD CONSTRAINT "slot_fk_vehicle_assigner_id" FOREIGN KEY ("vehicle_assigner_id")
  REFERENCES "person" ("id") DEFERRABLE;

ALTER TABLE "transport" ADD CONSTRAINT "transport_fk_event_id" FOREIGN KEY ("event_id")
  REFERENCES "event" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "transport" ADD CONSTRAINT "transport_fk_vehicle_id" FOREIGN KEY ("vehicle_id")
  REFERENCES "vehicle" ("id") DEFERRABLE;

ALTER TABLE "transport" ADD CONSTRAINT "transport_fk_vehicle_assigner_id" FOREIGN KEY ("vehicle_assigner_id")
  REFERENCES "person" ("id") DEFERRABLE;

ALTER TABLE "vehicle_request" ADD CONSTRAINT "vehicle_request_fk_event_id" FOREIGN KEY ("event_id")
  REFERENCES "event" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "vehicle_request" ADD CONSTRAINT "vehicle_request_fk_type_id" FOREIGN KEY ("type_id")
  REFERENCES "type" ("id") DEFERRABLE;

ALTER TABLE "leg" ADD CONSTRAINT "leg_fk_beginning_id" FOREIGN KEY ("beginning_id")
  REFERENCES "location" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "leg" ADD CONSTRAINT "leg_fk_ending_id" FOREIGN KEY ("ending_id")
  REFERENCES "location" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "leg" ADD CONSTRAINT "leg_fk_journey_id" FOREIGN KEY ("journey_id")
  REFERENCES "journey" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "leg" ADD CONSTRAINT "leg_fk_operator_id" FOREIGN KEY ("operator_id")
  REFERENCES "person" ("id") DEFERRABLE;

ALTER TABLE "leg" ADD CONSTRAINT "leg_fk_vehicle_id" FOREIGN KEY ("vehicle_id")
  REFERENCES "vehicle" ("id") DEFERRABLE;
