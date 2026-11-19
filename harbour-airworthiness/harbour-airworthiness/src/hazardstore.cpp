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
    h.createdMs = obj[QStringLiteral("created")].toVariant().toLongLong();
    h.updatedMs = obj[QStringLiteral("updated")].toVariant().toLongLong();
    if (h.status.isEmpty())
        h.status = QStringLiteral("open");
    return h;
}

HazardStore::HazardStore(QObject *parent)
    : QAbstractListModel(parent)
{
    load();
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

QString HazardStore::storagePath() const
{
    QString base = QStandardPaths::writableLocation(QStandardPaths::DataLocation);
    return base + QStringLiteral("/hazards.json");
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
        if (m_filterStatus.isEmpty() || h.status == m_filterStatus)
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
    if (data.contains(QStringLiteral("dueDate")))
        h.dueDate = QDate::fromString(data[QStringLiteral("dueDate")].toString(), Qt::ISODate);
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
            return map;
        }
    }
    return map;
}

int HazardStore::highestRiskIndex() const
{
    int highest = 0;
    for (const Hazard &h : m_visible) {
        if (h.status == QStringLiteral("open"))
            highest = qMax(highest, h.riskIndex());  // keep numeric HRI for stats
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
    int n = 0;
    for (const Hazard &h : m_all) {
        if (h.severity == severity && h.likelihood == likelihood
                && h.status != QStringLiteral("closed"))
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
