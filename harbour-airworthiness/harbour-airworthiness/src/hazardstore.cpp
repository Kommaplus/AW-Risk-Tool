#include "hazardstore.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QStandardPaths>
#include <algorithm>

QJsonObject Hazard::toJson() const
{
    QJsonObject o;
    o[QStringLiteral("id")] = id;
    o[QStringLiteral("aircraft")] = aircraft;
    o[QStringLiteral("system")] = system;
    o[QStringLiteral("title")] = title;
    o[QStringLiteral("description")] = description;
    o[QStringLiteral("severity")] = severity;
    o[QStringLiteral("likelihood")] = likelihood;
    o[QStringLiteral("mitigation")] = mitigation;
    o[QStringLiteral("owner")] = owner;
    o[QStringLiteral("status")] = status;
    o[QStringLiteral("dueDate")] = dueDate.isValid() ? dueDate.toString(Qt::ISODate) : QString();
    o[QStringLiteral("acceptedBy")] = acceptedBy;
    o[QStringLiteral("acceptedDate")] = acceptedDate.isValid() ? acceptedDate.toString(Qt::ISODate) : QString();
    o[QStringLiteral("reviewInterval")] = reviewInterval;   // months, 0 = off
    o[QStringLiteral("reviewedDate")] = lastReviewed.isValid() ? lastReviewed.toString(Qt::ISODate) : QString();
    o[QStringLiteral("certBaseline")] = certBaseline;
    o[QStringLiteral("certCriteria")] = certCriteria;
    o[QStringLiteral("created")] = createdMs;
    o[QStringLiteral("updated")] = updatedMs;
    return o;
}

Hazard Hazard::fromJson(const QJsonObject &obj)
{
    Hazard h;
    h.id = obj[QStringLiteral("id")].toInt();
    h.aircraft = obj[QStringLiteral("aircraft")].toString();
    h.system = obj[QStringLiteral("system")].toString();
    h.title = obj[QStringLiteral("title")].toString();
    h.description = obj[QStringLiteral("description")].toString();
    h.severity = qBound(1, obj[QStringLiteral("severity")].toInt(), 4);
    h.likelihood = qBound(1, obj[QStringLiteral("likelihood")].toInt(), 5);
    h.mitigation = obj[QStringLiteral("mitigation")].toString();
    h.owner = obj[QStringLiteral("owner")].toString();
    h.status = obj[QStringLiteral("status")].toString();
    h.dueDate = QDate::fromString(obj[QStringLiteral("dueDate")].toString(), Qt::ISODate);
    // Optional fields: hazards saved by older versions of the app have no
    // acceptedBy/acceptedDate/reviewInterval/reviewedDate/certBaseline/
    // certCriteria keys, and fromJson() then leaves them empty or off.
    h.acceptedBy = obj[QStringLiteral("acceptedBy")].toString();
    h.acceptedDate = QDate::fromString(obj[QStringLiteral("acceptedDate")].toString(), Qt::ISODate);
    h.reviewInterval = qMax(0, obj[QStringLiteral("reviewInterval")].toInt());
    h.lastReviewed = QDate::fromString(obj[QStringLiteral("reviewedDate")].toString(), Qt::ISODate);
    h.certBaseline = obj[QStringLiteral("certBaseline")].toString();
    h.certCriteria = obj[QStringLiteral("certCriteria")].toString();
    h.createdMs = obj[QStringLiteral("created")].toVariant().toLongLong();
    h.updatedMs = obj[QStringLiteral("updated")].toVariant().toLongLong();
    if (h.status.isEmpty())
        h.status = QStringLiteral("open");
    return h;
}

QDate Hazard::nextReviewDate() const
{
    // A recurring review is always based on the last review; a hazard that
    // has never been reviewed counts from its creation date.
    if (reviewInterval <= 0)
        return QDate();
    QDate base = lastReviewed.isValid()
            ? lastReviewed
            : QDateTime::fromMSecsSinceEpoch(createdMs).date();
    if (!base.isValid())
        return QDate();
    return base.addMonths(reviewInterval);
}

HazardStore::HazardStore(QObject *parent)
    : QAbstractListModel(parent)
{
    load();
    loadLookups();
    repopulate();
}

// AWB-150B Attachment 2, Table 4 (same matrix as MIL-STD-882E Table III
// and AFI 62-601 Table A2.2). Rows are probability levels A..E,
// columns are severity categories 1..4; values are the numeric
// Risk Assessment Code 1..20:
//   1-5 High, 6-9 Serious, 10-17 Medium, 18-20 Low.
static const int s_awb150Rac[5][4] = {
    // I          II          III         IV
    {  1,          3,          7,         13},   // A Frequent
    {  2,          5,          9,         16},   // B Probable
    {  4,          6,         11,         18},   // C Occasional
    {  8,         10,         14,         19},   // D Remote
    { 12,         15,         17,         20},   // E Improbable
};

int HazardStore::rac(int severity, int likelihood)
{
    const int s = qBound(1, severity, 4);
    const int l = qBound(1, likelihood, 5);
    return s_awb150Rac[l - 1][s - 1];
}

int HazardStore::riskLevel(int severity, int likelihood)
{
    const int r = rac(severity, likelihood);
    if (r <= 5)
        return 0;   // High
    if (r <= 9)
        return 1;   // Serious
    if (r <= 17)
        return 2;   // Medium
    return 3;       // Low
}

QString HazardStore::riskCategory(int severity, int likelihood)
{
    switch (riskLevel(severity, likelihood)) {
    case 0: return QStringLiteral("High");
    case 1: return QStringLiteral("Serious");
    case 2: return QStringLiteral("Medium");
    default: return QStringLiteral("Low");
    }
}

QString HazardStore::riskColor(int severity, int likelihood)
{
    switch (riskLevel(severity, likelihood)) {
    case 0: return QStringLiteral("#e74c3c");   // High - red
    case 1: return QStringLiteral("#e67e22");   // Serious - orange
    case 2: return QStringLiteral("#f1c40f");   // Medium - amber
    default: return QStringLiteral("#2ecc71"); // Low - green
    }
}

QString HazardStore::severityName(int severity)
{
    switch (qBound(1, severity, 4)) {
    case 1: return QStringLiteral("I — Catastrophic");
    case 2: return QStringLiteral("II — Critical");
    case 3: return QStringLiteral("III — Marginal");
    default: return QStringLiteral("IV — Negligible");
    }
}

QString HazardStore::likelihoodName(int likelihood)
{
    switch (qBound(1, likelihood, 5)) {
    case 1: return QStringLiteral("A — Frequent");
    case 2: return QStringLiteral("B — Probable");
    case 3: return QStringLiteral("C — Occasional");
    case 4: return QStringLiteral("D — Remote");
    default: return QStringLiteral("E — Improbable");
    }
}

QString HazardStore::severityCode(int severity)
{
    switch (qBound(1, severity, 4)) {
    case 1: return QStringLiteral("I");
    case 2: return QStringLiteral("II");
    case 3: return QStringLiteral("III");
    default: return QStringLiteral("IV");
    }
}

QString HazardStore::likelihoodCode(int likelihood)
{
    switch (qBound(1, likelihood, 5)) {
    case 1: return QStringLiteral("A");
    case 2: return QStringLiteral("B");
    case 3: return QStringLiteral("C");
    case 4: return QStringLiteral("D");
    default: return QStringLiteral("E");
    }
}

QString HazardStore::statusLabelFor(const QString &status) const
{
    // Stored status values are lowercase keys in the JSON data
    // ("open", "mitigated", "alarp", "transferred", "closed"); these
    // labels are the only user-facing forms. Unknown values show as-is.
    if (status == QStringLiteral("open"))
        return QStringLiteral("Open");
    if (status == QStringLiteral("mitigated"))
        return QStringLiteral("Mitigated");
    if (status == QStringLiteral("alarp"))
        return QStringLiteral("As Low As Reasonably Practicable (ALARP)");
    if (status == QStringLiteral("transferred"))
        return QStringLiteral("Transferred to Operational Risk");
    if (status == QStringLiteral("closed"))
        return QStringLiteral("Closed");
    return status;
}

QString HazardStore::reviewIntervalLabelFor(int months) const
{
    // Values match ReviewIntervalPickerPage.qml; months <= 0 disables
    // the recurring review.
    switch (months) {
    case 0: return QStringLiteral("Off");
    case 1: return QStringLiteral("Every month");
    default: return QStringLiteral("Every %1 months").arg(months);
    }
}

// Built-in ATA 100 chapters (fixed-wing subset), including the military
// chapters "25-70 - Crew Escape System" and "94 - Weapons". These strings
// are the exact values saved in hazards.json, so they must never be
// renamed or translated. User-added chapters are stored in lookups.json.
static QStringList builtinAtaChapters()
{
    QStringList list;
    list << QStringLiteral("21 - Air Conditioning & Pressurization")
         << QStringLiteral("22 - Auto Flight")
         << QStringLiteral("23 - Communications")
         << QStringLiteral("24 - Electrical Power")
         << QStringLiteral("25 - Equipment & Furnishings")
         << QStringLiteral("25-70 - Crew Escape System")
         << QStringLiteral("26 - Fire Protection")
         << QStringLiteral("27 - Flight Controls")
         << QStringLiteral("28 - Fuel")
         << QStringLiteral("29 - Hydraulics")
         << QStringLiteral("30 - Ice & Rain Protection")
         << QStringLiteral("31 - Indicating & Recording")
         << QStringLiteral("32 - Landing Gear")
         << QStringLiteral("33 - Lights")
         << QStringLiteral("34 - Navigation")
         << QStringLiteral("35 - Oxygen")
         << QStringLiteral("36 - Pneumatics")
         << QStringLiteral("38 - Water & Waste")
         << QStringLiteral("44 - Cabin Systems")
         << QStringLiteral("45 - Central & Integrated System")
         << QStringLiteral("46 - Information Systems")
         << QStringLiteral("49 - APU")
         << QStringLiteral("51 - Standard Practices & Structures")
         << QStringLiteral("52 - Doors")
         << QStringLiteral("53 - Fuselage")
         << QStringLiteral("54 - Nacelles & Pylons")
         << QStringLiteral("55 - Stabilizers")
         << QStringLiteral("56 - Windows")
         << QStringLiteral("57 - Wings")
         << QStringLiteral("61 - Propellers")
         << QStringLiteral("70 - Standard Practices (Engine)")
         << QStringLiteral("71 - Power Plant")
         << QStringLiteral("72 - Engine")
         << QStringLiteral("73 - Engine Fuel & Control")
         << QStringLiteral("74 - Ignition")
         << QStringLiteral("75 - Engine Air & Bleed")
         << QStringLiteral("76 - Engine Controls")
         << QStringLiteral("77 - Engine Indicating")
         << QStringLiteral("78 - Exhaust")
         << QStringLiteral("79 - Engine Oil")
         << QStringLiteral("80 - Engine Starting")
         << QStringLiteral("83 - Accessory Gearboxes")
         << QStringLiteral("94 - Weapons");
    return list;
}

// Built-in certification baselines. "FAR Parts" and "EASA CS" are kept
// generic on purpose: they cover several aircraft categories (e.g.
// FAR Part 23/25, CS-23/CS-25). User-added baselines are stored in
// lookups.json and are never renamed by the app.
static QStringList builtinBaselines()
{
    QStringList list;
    list << QStringLiteral("MIL-HDBK-516C")
         << QStringLiteral("EMACC")
         << QStringLiteral("FAR Parts")
         << QStringLiteral("EASA CS");
    return list;
}

QStringList HazardStore::ataChapters() const
{
    return builtinAtaChapters() + m_customAtaChapters;
}

QStringList HazardStore::baselines() const
{
    return builtinBaselines() + m_customBaselines;
}

void HazardStore::addAtaChapter(const QString &chapter)
{
    const QString trimmed = chapter.trimmed();
    // Ignore empty entries and duplicates of anything already pickable.
    if (trimmed.isEmpty() || ataChapters().contains(trimmed))
        return;
    m_customAtaChapters.append(trimmed);
    std::sort(m_customAtaChapters.begin(), m_customAtaChapters.end());
    saveLookups();
    emit ataChaptersChanged();
}

void HazardStore::addBaseline(const QString &baseline)
{
    const QString trimmed = baseline.trimmed();
    if (trimmed.isEmpty() || baselines().contains(trimmed))
        return;
    m_customBaselines.append(trimmed);
    std::sort(m_customBaselines.begin(), m_customBaselines.end());
    saveLookups();
    emit baselinesChanged();
}

void HazardStore::removeAtaChapter(const QString &chapter)
{
    const QString c = chapter.trimmed();
    // Built-in chapters cannot be removed: saved hazards may use them.
    if (!m_customAtaChapters.contains(c))
        return;
    // Hazards that already saved this chapter keep their stored text;
    // only the pickable entry is removed.
    m_customAtaChapters.removeAll(c);
    saveLookups();
    emit ataChaptersChanged();
}

void HazardStore::renameAtaChapter(const QString &from, const QString &to)
{
    const QString a = from.trimmed();
    const QString b = to.trimmed();
    // Only user-added entries can be renamed, never onto an empty name.
    // Renaming onto an existing entry merges the two into one.
    if (a.isEmpty() || b.isEmpty() || a == b || !m_customAtaChapters.contains(a))
        return;
    m_customAtaChapters.removeAll(a);
    if (!ataChapters().contains(b)) {
        m_customAtaChapters.append(b);
        std::sort(m_customAtaChapters.begin(), m_customAtaChapters.end());
    }
    saveLookups();
    emit ataChaptersChanged();
    // Fixing a typo must follow the data: update every hazard that still
    // stores the old spelling.
    bool changed = false;
    for (Hazard &h : m_all) {
        if (h.system == a) {
            h.system = b;
            changed = true;
        }
    }
    if (changed)
        save();
    repopulate();
}

void HazardStore::removeBaseline(const QString &baseline)
{
    const QString c = baseline.trimmed();
    // Built-in baselines cannot be removed: saved hazards may use them.
    if (!m_customBaselines.contains(c))
        return;
    // Hazards that already saved this baseline keep their stored text;
    // only the pickable entry is removed.
    m_customBaselines.removeAll(c);
    saveLookups();
    emit baselinesChanged();
}

void HazardStore::renameBaseline(const QString &from, const QString &to)
{
    const QString a = from.trimmed();
    const QString b = to.trimmed();
    if (a.isEmpty() || b.isEmpty() || a == b || !m_customBaselines.contains(a))
        return;
    m_customBaselines.removeAll(a);
    if (!baselines().contains(b)) {
        m_customBaselines.append(b);
        std::sort(m_customBaselines.begin(), m_customBaselines.end());
    }
    saveLookups();
    emit baselinesChanged();
    // Fixing a typo must follow the data: update every hazard that still
    // stores the old spelling.
    bool changed = false;
    for (Hazard &h : m_all) {
        if (h.certBaseline == a) {
            h.certBaseline = b;
            changed = true;
        }
    }
    if (changed)
        save();
    // Keep an active main-list filter consistent with the rename.
    if (m_baselineFilter == a) {
        m_baselineFilter = b;
        emit baselineFilterChanged();
    }
    repopulate();
}

// Full path for an export file in the shared Documents folder, e.g.
// ".../Documents/AW-Risk-Tool-hazards-2026-11-22.csv". The Documents
// permission in the desktop file makes this folder visible inside the
// app sandbox; without it the write fails and "" is returned.
static QString exportFilePath(const QString &suffix)
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    const QString name = QStringLiteral("AW-Risk-Tool-hazards-%1.%2")
            .arg(QDate::currentDate().toString(QStringLiteral("yyyy-MM-dd")))
            .arg(suffix);
    return dir + QStringLiteral("/") + name;
}

// Minimal RFC 4180 quoting: fields containing the separator, a double
// quote or a line break are wrapped in double quotes, inner quotes
// doubled up.
static QString csvEscape(const QString &value)
{
    if (value.contains(QLatin1Char(';')) || value.contains(QLatin1Char('"'))
            || value.contains(QLatin1Char('\n')) || value.contains(QLatin1Char('\r')))
        return QStringLiteral("\"%1\"")
                .arg(QString(value).replace(QLatin1Char('"'), QStringLiteral("\"\"")));
    return value;
}

QString HazardStore::exportToCsv() const
{
    const QString path = exportFilePath(QStringLiteral("csv"));
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return QString();
    const QLatin1Char sep(';');
    // Semicolon separator: Excel/LibreOffice in Danish locales split on
    // ';' out of the box. Change this line to ',' for standard tools.
    QStringList header;
    header << "id" << "aircraft" << "system" << "title" << "description"
           << "severity" << "likelihood" << "RAC" << "risk category"
           << "mitigation" << "owner" << "status" << "due date"
           << "accepted by" << "acceptance date"
           << "review interval (months)" << "last reviewed" << "next review"
           << "certification baseline" << "criteria points"
           << "created" << "updated";
    QStringList lines;
    lines.append(header.join(sep));
    for (const Hazard &h : m_all) {
        QStringList row;
        row << QString::number(h.id)
            << csvEscape(h.aircraft)
            << csvEscape(h.system)
            << csvEscape(h.title)
            << csvEscape(h.description)
            << QString::number(h.severity)
            << QString::number(h.likelihood)
            << QString::number(rac(h.severity, h.likelihood))
            << csvEscape(riskCategory(h.severity, h.likelihood))
            << csvEscape(h.mitigation)
            << csvEscape(h.owner)
            << csvEscape(statusLabelFor(h.status))
            << csvEscape(h.dueDate.isValid() ? h.dueDate.toString(Qt::ISODate) : QString())
            << csvEscape(h.acceptedBy)
            << csvEscape(h.acceptedDate.isValid() ? h.acceptedDate.toString(Qt::ISODate) : QString())
            << QString::number(h.reviewInterval)
            << csvEscape(h.lastReviewed.isValid() ? h.lastReviewed.toString(Qt::ISODate) : QString())
            << csvEscape(h.nextReviewDate().isValid() ? h.nextReviewDate().toString(Qt::ISODate) : QString())
            << csvEscape(h.certBaseline)
            << csvEscape(h.certCriteria)
            << csvEscape(QDateTime::fromMSecsSinceEpoch(h.createdMs).toString(QStringLiteral("yyyy-MM-dd hh:mm")))
            << csvEscape(QDateTime::fromMSecsSinceEpoch(h.updatedMs).toString(QStringLiteral("yyyy-MM-dd hh:mm")));
        lines.append(row.join(sep));
    }
    // UTF-8 BOM so Excel detects the encoding (Danish characters).
    file.write("\xEF\xBB\xBF");
    file.write(lines.join(QLatin1Char('\n')).toUtf8());
    file.write("\n");
    return path;
}

QString HazardStore::exportToJson() const
{
    const QString path = exportFilePath(QStringLiteral("json"));
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return QString();
    // Same shape as the internal hazards.json, so the export doubles
    // as a backup of the whole register.
    QJsonArray array;
    for (const Hazard &h : m_all)
        array.append(h.toJson());
    file.write(QJsonDocument(array).toJson(QJsonDocument::Indented));
    return path;
}

QString HazardStore::storagePath() const
{
    QString base = QStandardPaths::writableLocation(QStandardPaths::DataLocation);
    return base + QStringLiteral("/hazards.json");
}

QString HazardStore::lookupPath() const
{
    QString base = QStandardPaths::writableLocation(QStandardPaths::DataLocation);
    return base + QStringLiteral("/lookups.json");
}

void HazardStore::load()
{
    QFile file(storagePath());
    if (!file.open(QIODevice::ReadOnly))
        return;
    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    const QJsonArray array = doc.array();
    for (const QJsonValue &v : array) {
        Hazard h = Hazard::fromJson(v.toObject());
        m_all.append(h);
        m_nextId = qMax(m_nextId, h.id + 1);
    }
}

// Custom picker entries live in their own JSON file so hazards.json stays
// untouched. A missing file simply means "no custom entries yet".
void HazardStore::loadLookups()
{
    QFile file(lookupPath());
    if (!file.open(QIODevice::ReadOnly))
        return;
    const QJsonObject obj = QJsonDocument::fromJson(file.readAll()).object();
    m_customAtaChapters.clear();
    const QJsonArray ata = obj[QStringLiteral("ataChapters")].toArray();
    for (const QJsonValue &v : ata)
        m_customAtaChapters.append(v.toString());
    m_customBaselines.clear();
    const QJsonArray bases = obj[QStringLiteral("baselines")].toArray();
    for (const QJsonValue &v : bases)
        m_customBaselines.append(v.toString());
}

void HazardStore::saveLookups()
{
    QDir().mkpath(QFileInfo(lookupPath()).absolutePath());
    QJsonObject obj;
    QJsonArray ata;
    for (const QString &c : m_customAtaChapters)
        ata.append(c);
    obj[QStringLiteral("ataChapters")] = ata;
    QJsonArray bases;
    for (const QString &b : m_customBaselines)
        bases.append(b);
    obj[QStringLiteral("baselines")] = bases;
    QFile file(lookupPath());
    if (!file.open(QIODevice::WriteOnly))
        return;
    file.write(QJsonDocument(obj).toJson());
}

void HazardStore::save()
{
    QDir().mkpath(QFileInfo(storagePath()).absolutePath());
    QJsonArray array;
    for (const Hazard &h : m_all)
        array.append(h.toJson());
    QFile file(storagePath());
    if (!file.open(QIODevice::WriteOnly))
        return;
    file.write(QJsonDocument(array).toJson());
}

void HazardStore::repopulate()
{
    beginResetModel();
    m_visible.clear();
    for (const Hazard &h : m_all) {
        // "active" is a virtual filter: hazards still managed in this
        // register (open, mitigated, alarp). Closed and transferred
        // hazards only show up when no filter is set.
        const bool statusMatch = m_filterStatus.isEmpty()
                || h.status == m_filterStatus
                || (m_filterStatus == QStringLiteral("active")
                    && (h.status == QStringLiteral("open")
                        || h.status == QStringLiteral("mitigated")
                        || h.status == QStringLiteral("alarp")));
        // Optional certification baseline filter: empty = no filtering.
        const bool baselineMatch = m_baselineFilter.isEmpty()
                || h.certBaseline == m_baselineFilter;
        if (statusMatch && baselineMatch)
            m_visible.append(h);
    }
    std::sort(m_visible.begin(), m_visible.end(), [](const Hazard &a, const Hazard &b) {
        int la = riskLevel(a.severity, a.likelihood);
        int lb = riskLevel(b.severity, b.likelihood);
        if (la != lb)
            return la < lb;   // High (0) first
        return a.riskIndex() > b.riskIndex();
    });
    endResetModel();
    emit countChanged();
}

int HazardStore::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_visible.count();
}

QHash<int, QByteArray> HazardStore::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[IdRole] = "id";
    roles[AircraftRole] = "aircraft";
    roles[SystemRole] = "system";
    roles[TitleRole] = "title";
    roles[DescriptionRole] = "description";
    roles[SeverityRole] = "severity";
    roles[SeverityNameRole] = "severityName";
    roles[SeverityCodeRole] = "severityCode";
    roles[LikelihoodRole] = "likelihood";
    roles[LikelihoodNameRole] = "likelihoodName";
    roles[LikelihoodCodeRole] = "likelihoodCode";
    roles[RiskIndexRole] = "riskIndex";
    roles[RiskCategoryRole] = "riskCategory";
    roles[RiskColorRole] = "riskColor";
    roles[RacRole] = "rac";
    roles[MitigationRole] = "mitigation";
    roles[OwnerRole] = "owner";
    roles[StatusRole] = "status";
    roles[DueDateRole] = "dueDate";
    roles[CreatedRole] = "created";
    roles[UpdatedRole] = "updated";
    roles[HasDueDateRole] = "hasDueDate";
    roles[AcceptedByRole] = "acceptedBy";
    roles[AcceptedDateRole] = "acceptedDate";
    roles[HasAcceptedDateRole] = "hasAcceptedDate";
    roles[ReviewIntervalRole] = "reviewInterval";
    roles[ReviewedDateRole] = "reviewedDate";
    roles[NextReviewRole] = "nextReview";
    roles[ReviewDueRole] = "reviewDue";
    roles[CertBaselineRole] = "certBaseline";
    roles[CertCriteriaRole] = "certCriteria";
    return roles;
}

QVariant HazardStore::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_visible.count())
        return QVariant();
    const Hazard &h = m_visible.at(index.row());
    switch (role) {
    case IdRole: return h.id;
    case AircraftRole: return h.aircraft;
    case SystemRole: return h.system;
    case TitleRole: return h.title;
    case DescriptionRole: return h.description;
    case SeverityRole: return h.severity;
    case SeverityNameRole: return severityName(h.severity);
    case SeverityCodeRole: return severityCode(h.severity);
    case LikelihoodNameRole: return likelihoodName(h.likelihood);
    case LikelihoodCodeRole: return likelihoodCode(h.likelihood);
    case LikelihoodRole: return h.likelihood;
    case RiskIndexRole: return h.riskIndex();
    case RiskCategoryRole: return riskCategory(h.severity, h.likelihood);
    case RiskColorRole: return riskColor(h.severity, h.likelihood);
    case RacRole: return rac(h.severity, h.likelihood);
    case MitigationRole: return h.mitigation;
    case OwnerRole: return h.owner;
    case StatusRole: return h.status;
    case DueDateRole: return h.dueDate.isValid()
            ? h.dueDate.toString(QStringLiteral("dd MMM yyyy")) : QString();
    case HasDueDateRole: return h.dueDate.isValid();
    case AcceptedByRole: return h.acceptedBy;
    case AcceptedDateRole: return h.acceptedDate.isValid()
            ? h.acceptedDate.toString(QStringLiteral("dd MMM yyyy")) : QString();
    case HasAcceptedDateRole: return h.acceptedDate.isValid();
    case ReviewIntervalRole: return h.reviewInterval;
    case ReviewedDateRole: return h.lastReviewed.isValid()
            ? h.lastReviewed.toString(QStringLiteral("dd MMM yyyy")) : QString();
    case NextReviewRole: return h.nextReviewDate().isValid()
            ? h.nextReviewDate().toString(QStringLiteral("dd MMM yyyy")) : QString();
    case ReviewDueRole: {
        // A recurring review is only due while the hazard is actively
        // managed here; closed and transferred hazards are exempt.
        // ALARP hazards are NOT exempt: the risk still exists.
        const QDate next = h.nextReviewDate();
        return next.isValid() && next <= QDate::currentDate()
                && h.status != QStringLiteral("closed")
                && h.status != QStringLiteral("transferred");
    }
    case CertBaselineRole: return h.certBaseline;
    case CertCriteriaRole: return h.certCriteria;
    case CreatedRole: return h.createdMs;
    case UpdatedRole: return h.updatedMs;
    default: return QVariant();
    }
}

static void fillHazard(Hazard &h, const QVariantMap &data, qlonglong nowMs)
{
    if (data.contains(QStringLiteral("aircraft")))
        h.aircraft = data[QStringLiteral("aircraft")].toString();
    if (data.contains(QStringLiteral("system")))
        h.system = data[QStringLiteral("system")].toString();
    if (data.contains(QStringLiteral("title")))
        h.title = data[QStringLiteral("title")].toString();
    if (data.contains(QStringLiteral("description")))
        h.description = data[QStringLiteral("description")].toString();
    if (data.contains(QStringLiteral("severity")))
        h.severity = qBound(1, data[QStringLiteral("severity")].toInt(), 4);
    if (data.contains(QStringLiteral("likelihood")))
        h.likelihood = qBound(1, data[QStringLiteral("likelihood")].toInt(), 5);
    if (data.contains(QStringLiteral("mitigation")))
        h.mitigation = data[QStringLiteral("mitigation")].toString();
    if (data.contains(QStringLiteral("owner")))
        h.owner = data[QStringLiteral("owner")].toString();
    if (data.contains(QStringLiteral("status")))
        h.status = data[QStringLiteral("status")].toString();
    // An empty string clears the date: QDate::fromString() returns an
    // invalid date, and the field shows "Not set" again.
    if (data.contains(QStringLiteral("dueDate")))
        h.dueDate = QDate::fromString(data[QStringLiteral("dueDate")].toString(), Qt::ISODate);
    if (data.contains(QStringLiteral("acceptedBy")))
        h.acceptedBy = data[QStringLiteral("acceptedBy")].toString();
    if (data.contains(QStringLiteral("acceptedDate")))
        h.acceptedDate = QDate::fromString(data[QStringLiteral("acceptedDate")].toString(), Qt::ISODate);
    if (data.contains(QStringLiteral("reviewInterval")))
        h.reviewInterval = qMax(0, data[QStringLiteral("reviewInterval")].toInt());
    if (data.contains(QStringLiteral("reviewedDate")))
        h.lastReviewed = QDate::fromString(data[QStringLiteral("reviewedDate")].toString(), Qt::ISODate);
    if (data.contains(QStringLiteral("certBaseline")))
        h.certBaseline = data[QStringLiteral("certBaseline")].toString();
    if (data.contains(QStringLiteral("certCriteria")))
        h.certCriteria = data[QStringLiteral("certCriteria")].toString();
    h.updatedMs = nowMs;
}

void HazardStore::addHazard(const QVariantMap &data)
{
    const qlonglong now = QDateTime::currentMSecsSinceEpoch();
    Hazard h;
    h.id = m_nextId++;
    h.createdMs = now;
    h.status = QStringLiteral("open");
    fillHazard(h, data, now);
    m_all.append(h);
    save();
    repopulate();
}

void HazardStore::updateHazard(int id, const QVariantMap &data)
{
    for (Hazard &h : m_all) {
        if (h.id == id) {
            fillHazard(h, data, QDateTime::currentMSecsSinceEpoch());
            save();
            repopulate();
            return;
        }
    }
}

void HazardStore::removeHazard(int id)
{
    for (int i = 0; i < m_all.count(); ++i) {
        if (m_all.at(i).id == id) {
            m_all.removeAt(i);
            save();
            repopulate();
            return;
        }
    }
}

QVariantMap HazardStore::getHazard(int id) const
{
    QVariantMap map;
    for (const Hazard &h : m_all) {
        if (h.id == id) {
            map[QStringLiteral("id")] = h.id;
            map[QStringLiteral("aircraft")] = h.aircraft;
            map[QStringLiteral("system")] = h.system;
            map[QStringLiteral("title")] = h.title;
            map[QStringLiteral("description")] = h.description;
            map[QStringLiteral("severity")] = h.severity;
            map[QStringLiteral("likelihood")] = h.likelihood;
            map[QStringLiteral("mitigation")] = h.mitigation;
            map[QStringLiteral("owner")] = h.owner;
            map[QStringLiteral("status")] = h.status;
            map[QStringLiteral("dueDate")] = h.dueDate.isValid()
                    ? h.dueDate.toString(Qt::ISODate) : QString();
            map[QStringLiteral("acceptedBy")] = h.acceptedBy;
            map[QStringLiteral("acceptedDate")] = h.acceptedDate.isValid()
                    ? h.acceptedDate.toString(Qt::ISODate) : QString();
            map[QStringLiteral("reviewInterval")] = h.reviewInterval;
            map[QStringLiteral("reviewedDate")] = h.lastReviewed.isValid()
                    ? h.lastReviewed.toString(Qt::ISODate) : QString();
            map[QStringLiteral("certBaseline")] = h.certBaseline;
            map[QStringLiteral("certCriteria")] = h.certCriteria;
            // The next review date and the overdue flag are derived data,
            // computed here so the detail page can show them without
            // duplicating the calculation in QML.
            const QDate next = h.nextReviewDate();
            map[QStringLiteral("nextReview")] = next.isValid()
                    ? next.toString(Qt::ISODate) : QString();
            map[QStringLiteral("reviewDue")] = next.isValid()
                    && next <= QDate::currentDate()
                    && h.status != QStringLiteral("closed")
                    && h.status != QStringLiteral("transferred");
            return map;
        }
    }
    return map;
}

int HazardStore::highestRiskIndex() const
{
    // Cover statistics: show the AWB-150 numeric RAC (1-20), not the
    // plain severity*likelihood product, so cover matches the matrix.
    int highest = 0;
    for (const Hazard &h : m_visible) {
        if (h.status == QStringLiteral("open"))
            highest = qMax(highest, rac(h.severity, h.likelihood));
    }
    return highest;
}

int HazardStore::openCount() const
{
    int n = 0;
    for (const Hazard &h : m_all) {
        if (h.status == QStringLiteral("open"))
            ++n;
    }
    return n;
}

void HazardStore::reload()
{
    m_all.clear();
    m_nextId = 1;
    load();
    repopulate();
}

int HazardStore::countAt(int severity, int likelihood) const
{
    // Hazards transferred to the operational risk register no longer count
    // in this matrix (like closed ones): they are managed elsewhere.
    int n = 0;
    for (const Hazard &h : m_all) {
        if (h.severity == severity && h.likelihood == likelihood
                && h.status != QStringLiteral("closed")
                && h.status != QStringLiteral("transferred"))
            ++n;
    }
    return n;
}

void HazardStore::setFilterStatus(const QString &status)
{
    if (m_filterStatus == status)
        return;
    m_filterStatus = status;
    emit filterStatusChanged();
    repopulate();
}

void HazardStore::setBaselineFilter(const QString &baseline)
{
    if (m_baselineFilter == baseline)
        return;
    m_baselineFilter = baseline;
    emit baselineFilterChanged();
    repopulate();
}
